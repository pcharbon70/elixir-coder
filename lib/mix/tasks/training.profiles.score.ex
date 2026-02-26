defmodule Mix.Tasks.Training.Profiles.Score do
  @shortdoc "Score profile run metrics and select a default backend"

  @moduledoc """
  Scores two training profiles from benchmark run metrics and writes a report.

      mix training.profiles.score edifice fallback \\
        --left-runs data/reports/edifice-runs.json \\
        --right-runs data/reports/fallback-runs.json
  """

  use Mix.Task

  alias ElixirCoder.Training.ProfileBenchmark
  alias ElixirCoder.Training.Profiles

  @requirements ["app.config"]

  @switches [
    alpha: :float,
    iterations: :integer,
    left_runs: :string,
    output_dir: :string,
    right_runs: :string,
    seed: :integer,
    timestamp: :string
  ]

  @usage """
  Usage:
    mix training.profiles.score <left_profile> <right_profile> [options]

  Options:
    --left-runs <path>         JSON file containing left-profile run metrics
    --right-runs <path>        JSON file containing right-profile run metrics
    --output-dir <dir>         Directory for generated benchmark report
    --timestamp <value>        Timestamp suffix for report filename
    --alpha <float>            Significance threshold (default 0.05)
    --iterations <integer>     Permutation iterations (default 2000, min 100)
    --seed <integer>           Deterministic seed for permutation test
  """

  @impl Mix.Task
  def run(args) do
    {opts, positional, invalid} = OptionParser.parse(args, strict: @switches)
    validate_options!(invalid)

    case positional do
      [left_arg, right_arg] ->
        left_profile = parse_profile!(left_arg)
        right_profile = parse_profile!(right_arg)

        left_runs_path = required_path!(opts, :left_runs)
        right_runs_path = required_path!(opts, :right_runs)

        with {:ok, left_runs} <- load_runs(left_runs_path),
             {:ok, right_runs} <- load_runs(right_runs_path),
             {:ok, result} <-
               ProfileBenchmark.analyze(
                 left_profile,
                 right_profile,
                 left_runs,
                 right_runs,
                 task_opts(opts)
               ),
             {:ok, report_path} <- ProfileBenchmark.write_report(result, task_opts(opts)) do
          Mix.shell().info("benchmark report: #{report_path}")
          Mix.shell().info("selected profile: #{result.selected_profile}")
          Mix.shell().info("selected backend: #{result.selected_backend}")
          Mix.shell().info("objective score left: #{format_float(result.objective_scores.left)}")

          Mix.shell().info(
            "objective score right: #{format_float(result.objective_scores.right)}"
          )
        else
          {:error, reason} ->
            Mix.raise("failed to score training profiles: #{inspect(reason)}")
        end

      _other ->
        Mix.raise(@usage)
    end
  end

  defp validate_options!([]), do: :ok

  defp validate_options!(invalid) do
    invalid_text =
      Enum.map_join(invalid, ", ", fn
        {key, nil} -> "--#{key}"
        {key, value} -> "--#{key}=#{value}"
      end)

    Mix.raise("invalid options: #{invalid_text}\n\n#{@usage}")
  end

  defp parse_profile!(name) do
    available = Profiles.available_profiles()

    case Enum.find(available, &(Atom.to_string(&1) == name)) do
      nil ->
        Mix.raise("unknown profile #{inspect(name)}. Available: #{Enum.join(available, ", ")}")

      profile ->
        profile
    end
  end

  defp required_path!(opts, key) do
    case opts[key] do
      nil -> Mix.raise("missing required option --#{key}\n\n#{@usage}")
      path -> Path.expand(path, File.cwd!())
    end
  end

  defp load_runs(path) do
    with {:ok, content} <- File.read(path),
         {:ok, decoded} <- Jason.decode(content) do
      decode_runs(decoded)
    else
      {:error, reason} -> {:error, {:run_file_load_failed, path, reason}}
    end
  end

  defp decode_runs(decoded) when is_list(decoded) do
    decoded
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {run, index}, {:ok, acc} ->
      case normalize_run(run) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, reason} -> {:halt, {:error, {:invalid_run, index, reason}}}
      end
    end)
    |> case do
      {:ok, runs} -> {:ok, Enum.reverse(runs)}
      {:error, _reason} = error -> error
    end
  end

  defp decode_runs(other), do: {:error, {:invalid_runs_file_format, other}}

  defp normalize_run(run) when is_map(run) do
    metric_keys = ProfileBenchmark.required_metrics()

    Enum.reduce_while(metric_keys, {:ok, %{}}, fn key, {:ok, acc} ->
      case fetch_metric(run, key) do
        {:ok, value} when is_number(value) -> {:cont, {:ok, Map.put(acc, key, value * 1.0)}}
        {:ok, value} -> {:halt, {:error, {:invalid_metric_value, key, value}}}
        :error -> {:halt, {:error, {:missing_metric, key}}}
      end
    end)
  end

  defp normalize_run(other), do: {:error, {:invalid_run_format, other}}

  defp fetch_metric(run, key) do
    case Map.fetch(run, Atom.to_string(key)) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(run, key)
    end
  end

  defp task_opts(opts) do
    alpha =
      case opts[:alpha] do
        nil -> []
        value -> [alpha: value]
      end

    iterations =
      case opts[:iterations] do
        nil -> []
        value -> [iterations: value]
      end

    seed =
      case opts[:seed] do
        nil -> []
        value -> [seed: value]
      end

    output_dir =
      case opts[:output_dir] do
        nil -> []
        dir -> [output_dir: Path.expand(dir, File.cwd!())]
      end

    timestamp =
      case opts[:timestamp] do
        nil -> []
        value -> [timestamp: value]
      end

    alpha ++ iterations ++ seed ++ output_dir ++ timestamp
  end

  defp format_float(number) do
    :erlang.float_to_binary(number * 1.0, decimals: 6)
  end
end
