defmodule ElixirCoder.Training.ProfileComparison do
  @moduledoc """
  Comparison and report generation for backend training profiles.

  A profile pair is considered comparable when:
  - all invariant keys match
  - differences are limited to explicitly allowed backend-selection keys
  """

  alias ElixirCoder.Training.Profiles

  @invariant_keys [:seed, :objective_weights, :required_features]
  @allowed_difference_keys [:profile, :backend, :fallback_backend, :allow_fallback?]

  @type profile :: keyword()
  @type profile_name :: Profiles.profile_name()

  @type invariant_failure :: %{key: atom(), left: term(), right: term()}

  @type result :: %{
          comparable?: boolean(),
          differing_keys: [atom()],
          invariant_failures: [invariant_failure()],
          left_profile: profile(),
          left_profile_name: atom() | nil,
          right_profile: profile(),
          right_profile_name: atom() | nil,
          unexpected_differences: [atom()]
        }

  @spec compare(profile_name(), profile_name()) :: {:ok, result()} | {:error, term()}
  def compare(left_name, right_name) when is_atom(left_name) and is_atom(right_name) do
    with {:ok, left_profile} <- Profiles.load(left_name),
         {:ok, right_profile} <- Profiles.load(right_name) do
      {:ok, analyze(left_profile, right_profile, left_name, right_name)}
    end
  end

  @spec compare(profile(), profile()) :: result()
  def compare(left_profile, right_profile)
      when is_list(left_profile) and is_list(right_profile) do
    analyze(left_profile, right_profile, profile_name(left_profile), profile_name(right_profile))
  end

  @spec write_report(profile_name() | profile(), profile_name() | profile(), keyword()) ::
          {:ok, String.t(), result()} | {:error, term()}
  def write_report(left, right, opts \\ [])

  def write_report(left_name, right_name, opts)
      when is_atom(left_name) and is_atom(right_name) and is_list(opts) do
    with {:ok, comparison} <- compare(left_name, right_name),
         :ok <- validate_requirement(comparison, opts),
         {:ok, path} <- persist_report(comparison, left_name, right_name, opts) do
      {:ok, path, comparison}
    end
  end

  def write_report(left_profile, right_profile, opts)
      when is_list(left_profile) and is_list(right_profile) and is_list(opts) do
    comparison = compare(left_profile, right_profile)
    left_name = profile_name(left_profile) || :left
    right_name = profile_name(right_profile) || :right

    with :ok <- validate_requirement(comparison, opts),
         {:ok, path} <- persist_report(comparison, left_name, right_name, opts) do
      {:ok, path, comparison}
    end
  end

  defp analyze(left_profile, right_profile, left_name, right_name) do
    keys =
      (Keyword.keys(left_profile) ++ Keyword.keys(right_profile))
      |> Enum.uniq()
      |> Enum.sort()

    differing_keys =
      Enum.filter(keys, fn key ->
        Keyword.get(left_profile, key) != Keyword.get(right_profile, key)
      end)

    invariant_failures =
      Enum.flat_map(@invariant_keys, fn key ->
        left_value = Keyword.get(left_profile, key)
        right_value = Keyword.get(right_profile, key)

        if left_value == right_value do
          []
        else
          [%{key: key, left: left_value, right: right_value}]
        end
      end)

    unexpected_differences = differing_keys -- @allowed_difference_keys

    %{
      comparable?: invariant_failures == [] and unexpected_differences == [],
      differing_keys: differing_keys,
      invariant_failures: invariant_failures,
      left_profile: left_profile,
      left_profile_name: left_name,
      right_profile: right_profile,
      right_profile_name: right_name,
      unexpected_differences: unexpected_differences
    }
  end

  defp profile_name(profile) do
    Keyword.get(profile, :profile)
  end

  defp validate_requirement(comparison, opts) do
    require_comparable? = Keyword.get(opts, :require_comparable?, false)

    if require_comparable? and not comparison.comparable? do
      {:error, {:profiles_not_comparable, comparison}}
    else
      :ok
    end
  end

  defp persist_report(comparison, left_name, right_name, opts) do
    output_dir = Keyword.get(opts, :output_dir, Path.expand("data/reports", File.cwd!()))
    timestamp = Keyword.get(opts, :timestamp, timestamp())

    file_name =
      "training-profile-comparison-#{left_name}-vs-#{right_name}-#{timestamp}.md"

    output_path = Path.join(output_dir, file_name)

    :ok = File.mkdir_p(output_dir)
    :ok = File.write(output_path, render_report(comparison))

    {:ok, output_path}
  end

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601(:basic)
    |> String.replace(~r/[^\dTZ]/, "")
  end

  defp render_report(comparison) do
    invariant_section =
      if comparison.invariant_failures == [] do
        "- PASS: all invariant keys match\n"
      else
        comparison.invariant_failures
        |> Enum.map(fn failure ->
          "- FAIL `#{failure.key}`: left=#{inspect(failure.left)} right=#{inspect(failure.right)}"
        end)
        |> Enum.join("\n")
        |> Kernel.<>("\n")
      end

    unexpected_section =
      if comparison.unexpected_differences == [] do
        "- none\n"
      else
        comparison.unexpected_differences
        |> Enum.map(&"- `#{&1}`")
        |> Enum.join("\n")
        |> Kernel.<>("\n")
      end

    differing_keys_section =
      if comparison.differing_keys == [] do
        "- none\n"
      else
        comparison.differing_keys
        |> Enum.map(&"- `#{&1}`")
        |> Enum.join("\n")
        |> Kernel.<>("\n")
      end

    """
    # Training Profile Comparison

    - Left profile: `#{comparison.left_profile_name}`
    - Right profile: `#{comparison.right_profile_name}`
    - Comparable: `#{comparison.comparable?}`

    ## Differing Keys
    #{differing_keys_section}

    ## Invariant Checks
    #{invariant_section}

    ## Unexpected Differences
    #{unexpected_section}
    """
  end
end
