defmodule ElixirCoder.Inference.Backend do
  @moduledoc """
  Backend resolution and adapter hooks for inference.

  This module keeps inference backend selection explicit and returns structured
  descriptors that are safe to consume by serving code.
  """

  alias ElixirCoder.Backend.CapabilityRegistry
  alias ElixirCoder.Backend.Resolver

  @type backend :: CapabilityRegistry.backend()
  @type feature :: CapabilityRegistry.feature()

  @type resolution :: %{
          backend: backend(),
          checkpoint_backend: backend() | nil,
          fallback?: boolean(),
          policy_mode: :warn | :enforce,
          required_features: [feature()],
          requested_backend: backend()
        }

  @spec resolve(map(), keyword()) ::
          {:ok, resolution()} | {:error, {:unsupported_features, map()}}
  def resolve(checkpoint_metadata, opts \\ [])
      when is_map(checkpoint_metadata) and is_list(opts) do
    requested_backend =
      Keyword.get(opts, :backend, Map.get(checkpoint_metadata, :backend, :edifice))

    required_features =
      Keyword.get(opts, :required_features, [:inference_generation])

    policy_mode = Keyword.get(opts, :policy_mode, :warn)

    with {:ok, selected_backend, metadata} <-
           Resolver.resolve(requested_backend, required_features) do
      {:ok,
       %{
         backend: selected_backend,
         checkpoint_backend: Map.get(checkpoint_metadata, :backend),
         fallback?: metadata.fallback?,
         policy_mode: policy_mode,
         required_features: required_features,
         requested_backend: requested_backend
       }}
    end
  end

  @spec generate_step(term(), term(), map(), keyword()) ::
          {:ok,
           %{backend: backend(), generation_state: map(), input: term(), model_state: term()}}
          | {:error, {:unsupported_features, map()}}
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
         model_state: model_state
       }}
    end
  end

  @spec apply_adapter(term(), map(), keyword()) ::
          {:ok, %{adapter: map(), backend: backend(), model_state: term()}}
          | {:error, {:unsupported_features, map()}}
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
         model_state: model_state
       }}
    end
  end
end
