defmodule ElixirCoder.Training.RunMetadata do
  @moduledoc """
  Backend-aware training run metadata and telemetry helpers.

  This module centralizes:
  - checkpoint metadata payloads used by train/load flows
  - backend labels attached to training telemetry events
  - backend mismatch alerts between training artifacts and runtime
  """

  alias ElixirCoder.Backend.CapabilityRegistry
  alias ElixirCoder.Backend.Runtime
  alias ElixirCoder.Training.ProfileRunner
  alias ElixirCoder.Training.Profiles

  @metric_event [:elixir_coder, :training, :metric]
  @backend_mismatch_event [:elixir_coder, :training, :backend_mismatch]

  @type metadata :: %{
          allow_fallback?: boolean(),
          backend: CapabilityRegistry.backend(),
          capabilities: [CapabilityRegistry.feature()],
          fallback?: boolean(),
          fallback_backend: CapabilityRegistry.backend(),
          generated_at: String.t(),
          missing_features: [CapabilityRegistry.feature()],
          objective_weights: map() | nil,
          profile: Profiles.profile_name(),
          requested_backend: CapabilityRegistry.backend(),
          required_features: [CapabilityRegistry.feature()],
          run_id: String.t(),
          runtime_overrides: map(),
          seed: non_neg_integer()
        }

  @type mismatch_mode :: :warn | :enforce
  @type mismatch_details :: %{
          checkpoint_backend: CapabilityRegistry.backend() | nil,
          mode: mismatch_mode(),
          profile: Profiles.profile_name() | nil,
          requested_backend: CapabilityRegistry.backend() | nil,
          run_id: String.t() | nil,
          runtime_backend: CapabilityRegistry.backend() | nil
        }

  @spec telemetry_event_names() :: %{backend_mismatch: [atom()], metric: [atom()]}
  def telemetry_event_names do
    %{
      backend_mismatch: @backend_mismatch_event,
      metric: @metric_event
    }
  end

  @spec from_profile(Profiles.profile_name(), keyword()) :: {:ok, metadata()} | {:error, term()}
  def from_profile(profile_name, opts \\ []) when is_atom(profile_name) and is_list(opts) do
    with {:ok, prepared} <- ProfileRunner.prepare_profile(profile_name) do
      {:ok, from_prepared(prepared, opts)}
    end
  end

  @spec from_prepared(ProfileRunner.prepared_profile(), keyword()) :: metadata()
  def from_prepared(prepared, opts \\ []) when is_map(prepared) and is_list(opts) do
    run_id = Keyword.get(opts, :run_id, default_run_id(prepared.profile_name))
    generated_at = Keyword.get(opts, :generated_at, timestamp())

    %{
      allow_fallback?: prepared.resolution.config.allow_fallback?,
      backend: prepared.resolution.backend,
      capabilities: prepared.resolution.capabilities,
      fallback?: prepared.resolution.metadata.fallback?,
      fallback_backend: prepared.resolution.config.fallback_backend,
      generated_at: generated_at,
      missing_features: prepared.resolution.metadata.missing_features,
      objective_weights: prepared.objective_weights,
      profile: prepared.profile_name,
      requested_backend: prepared.resolution.config.requested_backend,
      required_features: prepared.profile[:required_features],
      run_id: run_id,
      runtime_overrides: Map.new(prepared.runtime_overrides),
      seed: prepared.seed
    }
  end

  @spec write(metadata(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def write(metadata, path) when is_map(metadata) and is_binary(path) do
    output_path = normalize_output_path(path)

    with :ok <- File.mkdir_p(Path.dirname(output_path)),
         :ok <- File.write(output_path, Jason.encode_to_iodata!(metadata, pretty: true)) do
      {:ok, output_path}
    end
  end

  @spec read(String.t()) :: {:ok, map()} | {:error, term()}
  def read(path) when is_binary(path) do
    with {:ok, content} <- File.read(path),
         {:ok, decoded} <- Jason.decode(content) do
      {:ok, decoded}
    end
  end

  @spec labels(map()) :: map()
  def labels(run_metadata) when is_map(run_metadata) do
    %{
      backend: fetch_atom_value(run_metadata, :backend, &parse_backend/1),
      fallback?: fetch_value(run_metadata, :fallback?),
      profile: fetch_atom_value(run_metadata, :profile, &parse_profile/1),
      requested_backend: fetch_atom_value(run_metadata, :requested_backend, &parse_backend/1),
      run_id: fetch_value(run_metadata, :run_id)
    }
  end

  @spec emit_metric(atom(), number(), map(), map()) :: :ok | {:error, term()}
  def emit_metric(metric, value, run_metadata, extra_metadata \\ %{})
      when is_atom(metric) and is_number(value) and is_map(run_metadata) and
             is_map(extra_metadata) do
    metadata =
      run_metadata
      |> labels()
      |> Map.put(:metric, metric)
      |> Map.merge(extra_metadata)

    :telemetry.execute(@metric_event, %{count: 1, value: value * 1.0}, metadata)
    :ok
  end

  @spec check_runtime_backend(map(), keyword()) ::
          :ok | {:warn, mismatch_details()} | {:error, mismatch_details()}
  def check_runtime_backend(checkpoint_metadata, opts \\ [])
      when is_map(checkpoint_metadata) and is_list(opts) do
    mode = Keyword.get(opts, :mode, :warn)

    with :ok <- validate_mode(mode) do
      checkpoint_backend = fetch_atom_value(checkpoint_metadata, :backend, &parse_backend/1)

      runtime_backend =
        Keyword.get_lazy(opts, :runtime_backend, fn ->
          Runtime.active_backend() || Runtime.requested_backend()
        end)

      details = %{
        checkpoint_backend: checkpoint_backend,
        mode: mode,
        profile: fetch_atom_value(checkpoint_metadata, :profile, &parse_profile/1),
        requested_backend:
          fetch_atom_value(checkpoint_metadata, :requested_backend, &parse_backend/1),
        run_id: fetch_value(checkpoint_metadata, :run_id),
        runtime_backend: runtime_backend
      }

      if checkpoint_backend == nil or runtime_backend == checkpoint_backend do
        :ok
      else
        :telemetry.execute(@backend_mismatch_event, %{count: 1}, details)

        case mode do
          :warn -> {:warn, details}
          :enforce -> {:error, details}
        end
      end
    end
  end

  defp normalize_output_path(path) do
    if Path.extname(path) == ".json" do
      path
    else
      Path.join(path, "checkpoint-metadata.json")
    end
    |> Path.expand(File.cwd!())
  end

  defp validate_mode(:warn), do: :ok
  defp validate_mode(:enforce), do: :ok
  defp validate_mode(other), do: {:error, {:invalid_mode, other}}

  defp fetch_value(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp fetch_atom_value(map, key, parser) do
    map
    |> fetch_value(key)
    |> parser.()
  end

  defp parse_backend(value) when is_atom(value) and value in [:edifice, :custom], do: value

  defp parse_backend(value) when is_binary(value) do
    Enum.find([:edifice, :custom], fn backend ->
      Atom.to_string(backend) == value
    end)
  end

  defp parse_backend(_other), do: nil

  defp parse_profile(value) when is_atom(value), do: value

  defp parse_profile(value) when is_binary(value) do
    available_profiles = Profiles.available_profiles()

    Enum.find(available_profiles, fn profile ->
      Atom.to_string(profile) == value
    end)
  end

  defp parse_profile(_other), do: nil

  defp default_run_id(profile_name) do
    "run-#{profile_name}-#{timestamp()}"
  end

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601(:basic)
    |> String.replace(~r/[^\dTZ]/, "")
  end
end
