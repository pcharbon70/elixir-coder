defmodule ElixirCoder.Inference.Backend do
  @moduledoc """
  Backend resolution and adapter hooks for inference.

  This module keeps inference backend selection explicit and returns structured
  descriptors that are safe to consume by serving code.

  It also emits telemetry events for backend decisions and can surface
  checkpoint/runtime backend mismatches in `:warn` or `:enforce` mode.
  """

  alias ElixirCoder.Backend.CapabilityRegistry
  alias ElixirCoder.Backend.Resolver
  alias ElixirCoder.Backend.Runtime
  alias ElixirCoder.Training.RunMetadata

  @type backend :: CapabilityRegistry.backend()
  @type feature :: CapabilityRegistry.feature()

  @resolved_event [:elixir_coder, :inference, :backend, :resolved]
  @mismatch_event [:elixir_coder, :inference, :backend, :mismatch]

  @type resolution :: %{
          backend: backend(),
          checkpoint_backend: backend() | nil,
          fallback?: boolean(),
          mismatch?: boolean(),
          mismatch_details: map() | nil,
          mismatch_mode: :warn | :enforce,
          policy_mode: :warn | :enforce,
          required_features: [feature()],
          requested_backend: backend()
        }

  @type request_metadata :: %{
          backend: backend(),
          checkpoint_backend: backend() | nil,
          fallback?: boolean(),
          mismatch?: boolean(),
          mismatch_mode: :warn | :enforce,
          policy_mode: :warn | :enforce,
          requested_backend: backend(),
          required_features: [feature()]
        }

  @spec telemetry_event_names() :: %{mismatch: [atom()], resolved: [atom()]}
  def telemetry_event_names do
    %{
      mismatch: @mismatch_event,
      resolved: @resolved_event
    }
  end

  @spec resolve(map(), keyword()) ::
          {:ok, resolution()}
          | {:error, {:unsupported_features, map()}}
          | {:error, {:backend_mismatch, map()}}
  def resolve(checkpoint_metadata, opts \\ [])
      when is_map(checkpoint_metadata) and is_list(opts) do
    requested_backend =
      Keyword.get(
        opts,
        :backend,
        parse_backend(fetch_value(checkpoint_metadata, :backend)) || Runtime.requested_backend()
      )

    required_features =
      Keyword.get(opts, :required_features, [:inference_generation])

    policy_mode = Keyword.get(opts, :policy_mode, :warn)
    mismatch_mode = Keyword.get(opts, :backend_mismatch_mode, :warn)
    allow_fallback? = Keyword.get(opts, :allow_fallback?, Runtime.allow_fallback?())
    fallback_backend = Keyword.get(opts, :fallback_backend, Runtime.fallback_backend())

    with {:ok, selected_backend, metadata} <-
           Resolver.resolve(requested_backend, required_features,
             allow_fallback?: allow_fallback?,
             fallback_backend: fallback_backend
           ),
         {:ok, mismatch?} <-
           apply_backend_mismatch_policy(
             checkpoint_metadata,
             selected_backend,
             mismatch_mode
           ) do
      checkpoint_backend = parse_backend(fetch_value(checkpoint_metadata, :backend))

      mismatch_details =
        mismatch_details(checkpoint_metadata, selected_backend, mismatch_mode, mismatch?)

      resolution = %{
        backend: selected_backend,
        checkpoint_backend: checkpoint_backend,
        fallback?: metadata.fallback?,
        mismatch?: mismatch?,
        mismatch_details: mismatch_details,
        mismatch_mode: mismatch_mode,
        policy_mode: policy_mode,
        required_features: required_features,
        requested_backend: requested_backend
      }

      emit_resolved(resolution)
      {:ok, resolution}
    end
  end

  @spec generate_step(term(), term(), map(), keyword()) ::
          {:ok,
           %{
             backend: backend(),
             generation_state: map(),
             input: term(),
             model_state: term(),
             request_metadata: request_metadata()
           }}
          | {:error, {:unsupported_features, map()}}
          | {:error, {:backend_mismatch, map()}}
  def generate_step(model_state, input, generation_state, opts \\ [])
      when is_map(generation_state) and is_list(opts) do
    checkpoint_metadata = Map.get(generation_state, :checkpoint_metadata, %{})

    with {:ok, resolution} <-
           resolve(
             checkpoint_metadata,
             Keyword.put_new(opts, :required_features, [:inference_generation])
           ) do
      {:ok,
       %{
         backend: resolution.backend,
         generation_state: generation_state,
         input: input,
         model_state: model_state,
         request_metadata: request_metadata(resolution)
       }}
    end
  end

  @spec apply_adapter(term(), map(), keyword()) ::
          {:ok,
           %{
             adapter: map(),
             backend: backend(),
             model_state: term(),
             request_metadata: request_metadata()
           }}
          | {:error, {:unsupported_features, map()}}
          | {:error, {:backend_mismatch, map()}}
  def apply_adapter(model_state, adapter, opts \\ []) when is_map(adapter) and is_list(opts) do
    checkpoint_metadata = Keyword.get(opts, :checkpoint_metadata, %{})

    with {:ok, resolution} <-
           resolve(
             checkpoint_metadata,
             Keyword.put_new(opts, :required_features, [:adapter_injection])
           ) do
      {:ok,
       %{
         adapter: adapter,
         backend: resolution.backend,
         model_state: model_state,
         request_metadata: request_metadata(resolution)
       }}
    end
  end

  defp apply_backend_mismatch_policy(checkpoint_metadata, runtime_backend, mode) do
    case RunMetadata.check_runtime_backend(checkpoint_metadata,
           runtime_backend: runtime_backend,
           mode: mode
         ) do
      :ok ->
        {:ok, false}

      {:warn, details} ->
        emit_mismatch(details)
        {:ok, true}

      {:error, %{checkpoint_backend: _checkpoint_backend} = details} ->
        emit_mismatch(details)
        {:error, {:backend_mismatch, details}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp mismatch_details(checkpoint_metadata, runtime_backend, mode, true) do
    %{
      checkpoint_backend: parse_backend(fetch_value(checkpoint_metadata, :backend)),
      mode: mode,
      requested_backend: parse_backend(fetch_value(checkpoint_metadata, :requested_backend)),
      runtime_backend: runtime_backend
    }
  end

  defp mismatch_details(_checkpoint_metadata, _runtime_backend, _mode, false), do: nil

  defp emit_resolved(%{
         backend: backend,
         checkpoint_backend: checkpoint_backend,
         fallback?: fallback?,
         mismatch?: mismatch?,
         mismatch_mode: mismatch_mode,
         policy_mode: policy_mode,
         required_features: required_features,
         requested_backend: requested_backend
       }) do
    measurements = %{
      count: 1,
      fallback: boolean_measurement(fallback?),
      mismatch: boolean_measurement(mismatch?)
    }

    metadata = %{
      backend: backend,
      checkpoint_backend: checkpoint_backend,
      fallback?: fallback?,
      mismatch?: mismatch?,
      mismatch_mode: mismatch_mode,
      policy_mode: policy_mode,
      requested_backend: requested_backend,
      required_features: required_features
    }

    :telemetry.execute(@resolved_event, measurements, metadata)
  end

  defp emit_mismatch(details) do
    :telemetry.execute(@mismatch_event, %{count: 1}, details)
  end

  defp request_metadata(%{
         backend: backend,
         checkpoint_backend: checkpoint_backend,
         fallback?: fallback?,
         mismatch?: mismatch?,
         mismatch_mode: mismatch_mode,
         policy_mode: policy_mode,
         requested_backend: requested_backend,
         required_features: required_features
       }) do
    %{
      backend: backend,
      checkpoint_backend: checkpoint_backend,
      fallback?: fallback?,
      mismatch?: mismatch?,
      mismatch_mode: mismatch_mode,
      policy_mode: policy_mode,
      requested_backend: requested_backend,
      required_features: required_features
    }
  end

  defp boolean_measurement(true), do: 1
  defp boolean_measurement(_), do: 0

  defp fetch_value(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp parse_backend(value) when is_atom(value) and value in [:edifice, :custom], do: value

  defp parse_backend(value) when is_binary(value) do
    Enum.find([:edifice, :custom], fn backend ->
      Atom.to_string(backend) == value
    end)
  end

  defp parse_backend(_other), do: nil
end
