defmodule ElixirCoder.Training.Profiles do
  @moduledoc """
  Loader and validator for training backend comparison profiles.

  Profiles are stored as `.exs` files under `config/training/` and return a
  keyword list.
  """

  alias ElixirCoder.Backend.CapabilityRegistry

  @required_keys [
    :profile,
    :backend,
    :fallback_backend,
    :allow_fallback?,
    :required_features,
    :seed
  ]
  @optional_keys [:objective_weights]
  @allowed_keys @required_keys ++ @optional_keys

  @type profile_name :: :edifice | :fallback
  @type profile :: keyword()

  @spec available_profiles() :: [profile_name()]
  def available_profiles do
    profiles_dir()
    |> Path.join("*.exs")
    |> Path.wildcard()
    |> Enum.map(&Path.basename(&1, ".exs"))
    |> Enum.map(&String.to_existing_atom/1)
    |> Enum.sort()
  rescue
    ArgumentError -> []
  end

  @spec profiles_dir() :: String.t()
  def profiles_dir do
    Path.expand("config/training", File.cwd!())
  end

  @spec profile_path(profile_name()) :: String.t()
  def profile_path(profile_name) when is_atom(profile_name) do
    Path.join(profiles_dir(), "#{profile_name}.exs")
  end

  @spec load(profile_name()) :: {:ok, profile()} | {:error, term()}
  def load(profile_name) when is_atom(profile_name) do
    path = profile_path(profile_name)

    if File.exists?(path) do
      {value, _binding} = Code.eval_file(path)
      validate(value, profile_name)
    else
      {:error, {:profile_not_found, profile_name}}
    end
  rescue
    error in Code.LoadError -> {:error, {:profile_load_failed, profile_name, error.message}}
    error in SyntaxError -> {:error, {:profile_syntax_error, profile_name, error.description}}
  end

  @spec load!(profile_name()) :: profile()
  def load!(profile_name) when is_atom(profile_name) do
    case load(profile_name) do
      {:ok, profile} ->
        profile

      {:error, reason} ->
        raise ArgumentError,
              "invalid training profile #{inspect(profile_name)}: #{inspect(reason)}"
    end
  end

  @spec runtime_overrides(profile_name()) :: {:ok, keyword()} | {:error, term()}
  def runtime_overrides(profile_name) when is_atom(profile_name) do
    with {:ok, profile} <- load(profile_name) do
      {:ok,
       [
         requested_backend: Keyword.fetch!(profile, :backend),
         fallback_backend: Keyword.fetch!(profile, :fallback_backend),
         allow_fallback?: Keyword.fetch!(profile, :allow_fallback?),
         required_features: Keyword.fetch!(profile, :required_features)
       ]}
    end
  end

  @spec compare(profile_name(), profile_name()) ::
          {:ok, %{left: profile(), right: profile(), differing_keys: [atom()]}} | {:error, term()}
  def compare(left_name, right_name) when is_atom(left_name) and is_atom(right_name) do
    with {:ok, left} <- load(left_name),
         {:ok, right} <- load(right_name) do
      keys =
        (Keyword.keys(left) ++ Keyword.keys(right))
        |> Enum.uniq()
        |> Enum.sort()

      differing_keys =
        Enum.filter(keys, fn key ->
          Keyword.get(left, key) != Keyword.get(right, key)
        end)

      {:ok, %{left: left, right: right, differing_keys: differing_keys}}
    end
  end

  defp validate(profile, expected_name) when is_list(profile) do
    with :ok <- validate_keys(profile),
         :ok <- validate_required(profile),
         :ok <- validate_profile_name(profile, expected_name),
         :ok <- validate_backend(profile, :backend),
         :ok <- validate_backend(profile, :fallback_backend),
         :ok <- validate_boolean(profile, :allow_fallback?),
         :ok <- validate_features(profile),
         :ok <- validate_seed(profile) do
      {:ok, profile}
    end
  end

  defp validate(_other, expected_name), do: {:error, {:invalid_profile_format, expected_name}}

  defp validate_keys(profile) do
    unknown_keys = Keyword.keys(profile) -- @allowed_keys

    if unknown_keys == [] do
      :ok
    else
      {:error, {:unknown_keys, unknown_keys}}
    end
  end

  defp validate_required(profile) do
    missing = Enum.reject(@required_keys, &Keyword.has_key?(profile, &1))

    if missing == [] do
      :ok
    else
      {:error, {:missing_required_keys, missing}}
    end
  end

  defp validate_profile_name(profile, expected_name) do
    case Keyword.get(profile, :profile) do
      ^expected_name -> :ok
      other -> {:error, {:profile_name_mismatch, expected_name, other}}
    end
  end

  defp validate_backend(profile, key) do
    backend = Keyword.get(profile, key)

    if backend in CapabilityRegistry.backends() do
      :ok
    else
      {:error, {:invalid_backend, key, backend}}
    end
  end

  defp validate_boolean(profile, key) do
    value = Keyword.get(profile, key)

    if is_boolean(value) do
      :ok
    else
      {:error, {:invalid_boolean, key, value}}
    end
  end

  defp validate_features(profile) do
    features = Keyword.get(profile, :required_features)

    cond do
      not is_list(features) ->
        {:error, {:invalid_required_features, features}}

      Enum.any?(features, &(not is_atom(&1))) ->
        {:error, {:invalid_required_feature_values, features}}

      true ->
        :ok
    end
  end

  defp validate_seed(profile) do
    seed = Keyword.get(profile, :seed)

    if is_integer(seed) and seed >= 0 do
      :ok
    else
      {:error, {:invalid_seed, seed}}
    end
  end
end
