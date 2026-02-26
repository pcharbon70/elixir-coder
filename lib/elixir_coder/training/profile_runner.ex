defmodule ElixirCoder.Training.ProfileRunner do
  @moduledoc """
  Runtime preparation and artifact generation for training profiles.

  This module turns static profile files into resolved runtime configurations and
  report artifacts for backend comparison runs.
  """

  alias ElixirCoder.Backend.Runtime
  alias ElixirCoder.Training.ProfileComparison
  alias ElixirCoder.Training.Profiles

  @type prepared_profile :: %{
          objective_weights: map() | nil,
          profile: keyword(),
          profile_name: atom(),
          resolution: Runtime.resolution(),
          runtime_overrides: keyword(),
          seed: non_neg_integer()
        }

  @type prepared_pair :: %{
          comparison: ProfileComparison.result(),
          left: prepared_profile(),
          right: prepared_profile()
        }

  @spec prepare_profile(Profiles.profile_name()) :: {:ok, prepared_profile()} | {:error, term()}
  def prepare_profile(profile_name) when is_atom(profile_name) do
    with {:ok, profile} <- Profiles.load(profile_name),
         {:ok, runtime_overrides} <- Profiles.runtime_overrides(profile_name),
         {:ok, resolution} <- Runtime.resolve(runtime_overrides) do
      {:ok,
       %{
         objective_weights: profile[:objective_weights],
         profile: profile,
         profile_name: profile_name,
         resolution: resolution,
         runtime_overrides: runtime_overrides,
         seed: profile[:seed]
       }}
    end
  end

  @spec prepare_pair(Profiles.profile_name(), Profiles.profile_name(), keyword()) ::
          {:ok, prepared_pair()} | {:error, term()}
  def prepare_pair(left_name, right_name, opts \\ [])
      when is_atom(left_name) and is_atom(right_name) and is_list(opts) do
    require_comparable? = Keyword.get(opts, :require_comparable?, true)

    with {:ok, left} <- prepare_profile(left_name),
         {:ok, right} <- prepare_profile(right_name),
         {:ok, comparison} <- ProfileComparison.compare(left_name, right_name),
         :ok <- validate_comparable(comparison, require_comparable?) do
      {:ok,
       %{
         comparison: comparison,
         left: left,
         right: right
       }}
    end
  end

  @spec write_pair_report(Profiles.profile_name(), Profiles.profile_name(), keyword()) ::
          {:ok, String.t(), prepared_pair()} | {:error, term()}
  def write_pair_report(left_name, right_name, opts \\ [])
      when is_atom(left_name) and is_atom(right_name) and is_list(opts) do
    require_comparable? = Keyword.get(opts, :require_comparable?, true)

    with {:ok, prepared_pair} <-
           prepare_pair(left_name, right_name, require_comparable?: require_comparable?),
         {:ok, path, _comparison} <-
           ProfileComparison.write_report(left_name, right_name, opts) do
      {:ok, path, prepared_pair}
    end
  end

  @spec write_manifest(Profiles.profile_name(), keyword()) ::
          {:ok, String.t(), map()} | {:error, term()}
  def write_manifest(profile_name, opts \\ []) when is_atom(profile_name) and is_list(opts) do
    with {:ok, prepared} <- prepare_profile(profile_name) do
      output_dir = Keyword.get(opts, :output_dir, Path.expand("data/reports", File.cwd!()))
      timestamp = Keyword.get(opts, :timestamp, timestamp())

      file_name = "training-profile-manifest-#{profile_name}-#{timestamp}.json"
      output_path = Path.join(output_dir, file_name)
      manifest = build_manifest(prepared)

      :ok = File.mkdir_p(output_dir)
      :ok = File.write(output_path, Jason.encode_to_iodata!(manifest, pretty: true))

      {:ok, output_path, manifest}
    end
  end

  defp build_manifest(prepared) do
    %{
      backend: prepared.resolution.backend,
      capabilities: prepared.resolution.capabilities,
      fallback?: prepared.resolution.metadata.fallback?,
      fallback_backend: prepared.resolution.config.fallback_backend,
      missing_features: prepared.resolution.metadata.missing_features,
      objective_weights: prepared.objective_weights,
      profile: prepared.profile_name,
      requested_backend: prepared.resolution.config.requested_backend,
      required_features: prepared.profile[:required_features],
      runtime_overrides: Map.new(prepared.runtime_overrides),
      seed: prepared.seed
    }
  end

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601(:basic)
    |> String.replace(~r/[^\dTZ]/, "")
  end

  defp validate_comparable(comparison, true) do
    if comparison.comparable? do
      :ok
    else
      {:error, {:profiles_not_comparable, comparison}}
    end
  end

  defp validate_comparable(_comparison, false), do: :ok
end
