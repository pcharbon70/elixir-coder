defmodule ElixirCoder.Training.ProfileBenchmark do
  @moduledoc """
  Comparative benchmark scoring for training backend profiles.

  This module supports Phase 5.12.2 by:
  - running matched benchmark windows for profile pairs
  - comparing key metrics with permutation-test significance checks
  - selecting the default profile/backend from an aggregate objective score
  - writing a markdown report artifact
  """

  alias ElixirCoder.Training.ProfileRunner
  alias ElixirCoder.Training.Profiles

  @metric_specs [
    %{key: :pass_at_1, direction: :higher, weight: 0.30},
    %{key: :policy_compliance_f1, direction: :higher, weight: 0.20},
    %{key: :throughput_tokens_per_sec, direction: :higher, weight: 0.20},
    %{key: :convergence_steps, direction: :lower, weight: 0.10},
    %{key: :internal_over_defensive_rate, direction: :lower, weight: 0.07},
    %{key: :boundary_under_handling_rate, direction: :lower, weight: 0.07},
    %{key: :silent_failure_rate, direction: :lower, weight: 0.06}
  ]

  @default_alpha 0.05
  @default_iterations 2_000
  @default_seed 42

  @type metric_key ::
          :boundary_under_handling_rate
          | :convergence_steps
          | :internal_over_defensive_rate
          | :pass_at_1
          | :policy_compliance_f1
          | :silent_failure_rate
          | :throughput_tokens_per_sec

  @type run_metrics :: %{required(metric_key()) => number()}

  @type metric_summary :: %{
          delta: float(),
          direction: :higher | :lower,
          key: metric_key(),
          left_mean: float(),
          normalized_delta: float(),
          p_value: float(),
          right_mean: float(),
          significant?: boolean(),
          weight: float(),
          winner: :left | :right | :tie
        }

  @type result :: %{
          alpha: float(),
          iterations: pos_integer(),
          left_backend: atom(),
          left_profile: Profiles.profile_name(),
          metric_summaries: [metric_summary()],
          objective_scores: %{left: float(), right: float()},
          right_backend: atom(),
          right_profile: Profiles.profile_name(),
          selected_backend: atom() | :tie,
          selected_profile: Profiles.profile_name() | :tie
        }

  @spec required_metrics() :: [metric_key()]
  def required_metrics do
    Enum.map(@metric_specs, & &1.key)
  end

  @spec run_matched_windows(
          Profiles.profile_name(),
          Profiles.profile_name(),
          (ProfileRunner.prepared_profile(), pos_integer() ->
             run_metrics() | {:ok, run_metrics()} | {:error, term()}),
          keyword()
        ) ::
          {:ok, %{left_runs: [run_metrics()], right_runs: [run_metrics()]}} | {:error, term()}
  def run_matched_windows(left_profile, right_profile, runner_fun, opts \\ [])
      when is_atom(left_profile) and is_atom(right_profile) and is_function(runner_fun, 2) do
    runs = Keyword.get(opts, :runs, 3)

    if is_integer(runs) and runs > 0 do
      with {:ok, left_prepared} <- ProfileRunner.prepare_profile(left_profile),
           {:ok, right_prepared} <- ProfileRunner.prepare_profile(right_profile),
           {:ok, left_runs} <- execute_runs(:left, left_prepared, runner_fun, runs),
           {:ok, right_runs} <- execute_runs(:right, right_prepared, runner_fun, runs) do
        {:ok, %{left_runs: left_runs, right_runs: right_runs}}
      end
    else
      {:error, {:invalid_runs_count, runs}}
    end
  end

  @spec analyze(
          Profiles.profile_name(),
          Profiles.profile_name(),
          [run_metrics()],
          [run_metrics()],
          keyword()
        ) ::
          {:ok, result()} | {:error, term()}
  def analyze(left_profile, right_profile, left_runs, right_runs, opts \\ [])
      when is_atom(left_profile) and is_atom(right_profile) and is_list(left_runs) and
             is_list(right_runs) do
    alpha = Keyword.get(opts, :alpha, @default_alpha)
    iterations = Keyword.get(opts, :iterations, @default_iterations)
    seed = Keyword.get(opts, :seed, @default_seed)

    with :ok <- validate_stat_config(alpha, iterations),
         :ok <- validate_runs(:left, left_runs),
         :ok <- validate_runs(:right, right_runs),
         {:ok, left_prepared} <- ProfileRunner.prepare_profile(left_profile),
         {:ok, right_prepared} <- ProfileRunner.prepare_profile(right_profile) do
      metric_summaries =
        Enum.with_index(@metric_specs, 1)
        |> Enum.map(fn {metric_spec, index} ->
          summarize_metric(metric_spec, left_runs, right_runs, alpha, iterations, seed + index)
        end)

      objective_scores = objective_scores(metric_summaries)

      selected_profile =
        cond do
          objective_scores.left > objective_scores.right -> left_profile
          objective_scores.right > objective_scores.left -> right_profile
          true -> :tie
        end

      selected_backend =
        case selected_profile do
          ^left_profile -> left_prepared.resolution.backend
          ^right_profile -> right_prepared.resolution.backend
          :tie -> :tie
        end

      {:ok,
       %{
         alpha: alpha,
         iterations: iterations,
         left_backend: left_prepared.resolution.backend,
         left_profile: left_profile,
         metric_summaries: metric_summaries,
         objective_scores: objective_scores,
         right_backend: right_prepared.resolution.backend,
         right_profile: right_profile,
         selected_backend: selected_backend,
         selected_profile: selected_profile
       }}
    end
  end

  @spec write_report(result(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def write_report(result, opts \\ []) when is_map(result) and is_list(opts) do
    output_dir = Keyword.get(opts, :output_dir, Path.expand("data/reports", File.cwd!()))
    timestamp = Keyword.get(opts, :timestamp, timestamp())

    file_name =
      "training-profile-benchmark-#{result.left_profile}-vs-#{result.right_profile}-#{timestamp}.md"

    output_path = Path.join(output_dir, file_name)

    :ok = File.mkdir_p(output_dir)
    :ok = File.write(output_path, render_report(result))

    {:ok, output_path}
  end

  defp execute_runs(side, prepared_profile, runner_fun, runs) do
    1..runs
    |> Enum.reduce_while({:ok, []}, fn run_number, {:ok, acc} ->
      case runner_fun.(prepared_profile, run_number) do
        {:ok, metrics} when is_map(metrics) ->
          case validate_run(side, run_number, metrics) do
            :ok -> {:cont, {:ok, [coerce_metric_values(metrics) | acc]}}
            {:error, _reason} = error -> {:halt, error}
          end

        {:error, reason} ->
          {:halt, {:error, {:run_failed, side, run_number, reason}}}

        metrics when is_map(metrics) ->
          case validate_run(side, run_number, metrics) do
            :ok -> {:cont, {:ok, [coerce_metric_values(metrics) | acc]}}
            {:error, _reason} = error -> {:halt, error}
          end

        other ->
          {:halt, {:error, {:invalid_runner_output, side, run_number, other}}}
      end
    end)
    |> case do
      {:ok, collected} -> {:ok, Enum.reverse(collected)}
      {:error, _reason} = error -> error
    end
  end

  defp summarize_metric(metric_spec, left_runs, right_runs, alpha, iterations, seed) do
    key = metric_spec.key
    direction = metric_spec.direction
    weight = metric_spec.weight

    left_values = Enum.map(left_runs, &metric_value!(&1, key))
    right_values = Enum.map(right_runs, &metric_value!(&1, key))

    left_mean = mean(left_values)
    right_mean = mean(right_values)
    delta = left_mean - right_mean

    {normalized_left, normalized_right, normalized_delta} =
      case direction do
        :higher -> {left_values, right_values, delta}
        :lower -> {Enum.map(left_values, &(-&1)), Enum.map(right_values, &(-&1)), -delta}
      end

    p_value = permutation_p_value(normalized_left, normalized_right, iterations, seed)
    raw_winner = winner_from_delta(normalized_delta)
    significant? = p_value < alpha and raw_winner != :tie
    winner = if significant?, do: raw_winner, else: :tie

    %{
      delta: delta,
      direction: direction,
      key: key,
      left_mean: left_mean,
      normalized_delta: normalized_delta,
      p_value: p_value,
      right_mean: right_mean,
      significant?: significant?,
      weight: weight,
      winner: winner
    }
  end

  defp metric_value!(run_metrics, key) do
    run_metrics
    |> Map.fetch!(key)
    |> Kernel.*(1.0)
  end

  defp objective_scores(metric_summaries) do
    Enum.reduce(metric_summaries, %{left: 0.0, right: 0.0}, fn summary, acc ->
      split_weight = summary.weight / 2.0

      case summary.winner do
        :left -> %{acc | left: acc.left + summary.weight}
        :right -> %{acc | right: acc.right + summary.weight}
        :tie -> %{acc | left: acc.left + split_weight, right: acc.right + split_weight}
      end
    end)
  end

  defp winner_from_delta(delta) when delta > 0.0, do: :left
  defp winner_from_delta(delta) when delta < 0.0, do: :right
  defp winner_from_delta(_delta), do: :tie

  defp mean(values) do
    Enum.sum(values) / length(values)
  end

  defp permutation_p_value(left_values, right_values, iterations, seed) do
    observed_delta = mean(left_values) - mean(right_values)

    if observed_delta == 0.0 do
      1.0
    else
      combined = left_values ++ right_values
      left_count = length(left_values)

      :rand.seed(:exsplus, seed_tuple(seed))

      extreme_count =
        Enum.reduce(1..iterations, 0, fn _, acc ->
          shuffled = Enum.shuffle(combined)
          {perm_left, perm_right} = Enum.split(shuffled, left_count)
          perm_delta = mean(perm_left) - mean(perm_right)

          if abs(perm_delta) >= abs(observed_delta) do
            acc + 1
          else
            acc
          end
        end)

      (extreme_count + 1) / (iterations + 1)
    end
  end

  defp seed_tuple(seed) do
    normalized_seed = abs(seed)

    {
      rem(normalized_seed + 1, 30_268) + 1,
      rem(normalized_seed * 3 + 7, 30_306) + 1,
      rem(normalized_seed * 5 + 11, 30_322) + 1
    }
  end

  defp validate_stat_config(alpha, iterations) do
    cond do
      not is_float(alpha) and not is_integer(alpha) ->
        {:error, {:invalid_alpha, alpha}}

      alpha <= 0 or alpha >= 1 ->
        {:error, {:invalid_alpha, alpha}}

      not is_integer(iterations) or iterations < 100 ->
        {:error, {:invalid_iterations, iterations}}

      true ->
        :ok
    end
  end

  defp validate_runs(side, runs) do
    cond do
      runs == [] ->
        {:error, {:empty_runs, side}}

      not is_list(runs) ->
        {:error, {:invalid_runs, side, runs}}

      true ->
        runs
        |> Enum.with_index(1)
        |> Enum.reduce_while(:ok, fn {run, index}, :ok ->
          case validate_run(side, index, run) do
            :ok -> {:cont, :ok}
            {:error, _reason} = error -> {:halt, error}
          end
        end)
    end
  end

  defp validate_run(side, run_index, run) when is_map(run) do
    Enum.reduce_while(required_metrics(), :ok, fn metric, :ok ->
      case Map.fetch(run, metric) do
        :error ->
          {:halt, {:error, {:missing_metric, side, run_index, metric}}}

        {:ok, value} when is_number(value) ->
          {:cont, :ok}

        {:ok, value} ->
          {:halt, {:error, {:invalid_metric_value, side, run_index, metric, value}}}
      end
    end)
  end

  defp validate_run(side, run_index, run) do
    {:error, {:invalid_run_format, side, run_index, run}}
  end

  defp coerce_metric_values(metrics) do
    Enum.reduce(required_metrics(), %{}, fn key, acc ->
      Map.put(acc, key, metric_value!(metrics, key))
    end)
  end

  defp render_report(result) do
    metric_table_rows =
      Enum.map_join(result.metric_summaries, "\n", fn summary ->
        [
          summary.key,
          summary.direction,
          format_float(summary.left_mean),
          format_float(summary.right_mean),
          format_float(summary.delta),
          format_float(summary.p_value),
          summary.significant?,
          summary.winner
        ]
        |> Enum.join(" | ")
        |> then(&"| #{&1} |")
      end)

    """
    # Training Profile Benchmark

    - Left profile: `#{result.left_profile}` (backend: `#{result.left_backend}`)
    - Right profile: `#{result.right_profile}` (backend: `#{result.right_backend}`)
    - Alpha: `#{format_float(result.alpha)}`
    - Permutation iterations: `#{result.iterations}`
    - Selected profile: `#{result.selected_profile}`
    - Selected backend: `#{result.selected_backend}`
    - Objective score (left): `#{format_float(result.objective_scores.left)}`
    - Objective score (right): `#{format_float(result.objective_scores.right)}`

    ## Metric Comparison

    | Metric | Direction | Left Mean | Right Mean | Delta (L-R) | p-value | Significant | Winner |
    |---|---|---:|---:|---:|---:|---|---|
    #{metric_table_rows}
    """
  end

  defp format_float(number) do
    :erlang.float_to_binary(number * 1.0, decimals: 6)
  end

  defp timestamp do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601(:basic)
    |> String.replace(~r/[^\dTZ]/, "")
  end
end
