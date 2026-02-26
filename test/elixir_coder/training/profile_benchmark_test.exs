defmodule ElixirCoder.Training.ProfileBenchmarkTest do
  use ExUnit.Case, async: true

  alias ElixirCoder.Training.ProfileBenchmark

  test "run_matched_windows executes runner for both profiles" do
    runner = fn prepared, run_number ->
      backend_bonus =
        case prepared.resolution.backend do
          :edifice -> 20.0
          :custom -> 0.0
        end

      %{
        boundary_under_handling_rate: 0.10,
        convergence_steps: 900.0 - run_number,
        internal_over_defensive_rate: 0.12,
        pass_at_1: 0.70 + run_number / 1_000.0,
        policy_compliance_f1: 0.76 + run_number / 2_000.0,
        silent_failure_rate: 0.03,
        throughput_tokens_per_sec: 1_050.0 + backend_bonus
      }
    end

    assert {:ok, results} =
             ProfileBenchmark.run_matched_windows(:edifice, :fallback, runner, runs: 4)

    assert length(results.left_runs) == 4
    assert length(results.right_runs) == 4

    assert hd(results.left_runs).throughput_tokens_per_sec >
             hd(results.right_runs).throughput_tokens_per_sec
  end

  test "analyze selects edifice profile when it wins weighted metrics" do
    left_runs = [
      metrics(
        pass_at_1: 0.76,
        policy_compliance_f1: 0.84,
        throughput_tokens_per_sec: 1_420.0,
        convergence_steps: 860.0
      ),
      metrics(
        pass_at_1: 0.77,
        policy_compliance_f1: 0.85,
        throughput_tokens_per_sec: 1_430.0,
        convergence_steps: 850.0
      ),
      metrics(
        pass_at_1: 0.78,
        policy_compliance_f1: 0.86,
        throughput_tokens_per_sec: 1_415.0,
        convergence_steps: 845.0
      ),
      metrics(
        pass_at_1: 0.79,
        policy_compliance_f1: 0.87,
        throughput_tokens_per_sec: 1_440.0,
        convergence_steps: 840.0
      )
    ]

    right_runs = [
      metrics(
        pass_at_1: 0.70,
        policy_compliance_f1: 0.77,
        throughput_tokens_per_sec: 1_120.0,
        convergence_steps: 980.0
      ),
      metrics(
        pass_at_1: 0.71,
        policy_compliance_f1: 0.78,
        throughput_tokens_per_sec: 1_130.0,
        convergence_steps: 975.0
      ),
      metrics(
        pass_at_1: 0.72,
        policy_compliance_f1: 0.79,
        throughput_tokens_per_sec: 1_140.0,
        convergence_steps: 970.0
      ),
      metrics(
        pass_at_1: 0.73,
        policy_compliance_f1: 0.80,
        throughput_tokens_per_sec: 1_115.0,
        convergence_steps: 965.0
      )
    ]

    assert {:ok, result} =
             ProfileBenchmark.analyze(:edifice, :fallback, left_runs, right_runs,
               alpha: 0.05,
               iterations: 1_000,
               seed: 123
             )

    assert result.selected_profile == :edifice
    assert result.selected_backend == :edifice
    assert result.objective_scores.left > result.objective_scores.right

    pass_metric = Enum.find(result.metric_summaries, &(&1.key == :pass_at_1))
    assert pass_metric.winner == :left
    assert pass_metric.significant?
  end

  test "analyze treats lower-is-better metrics correctly" do
    left_runs = [
      metrics(silent_failure_rate: 0.01, internal_over_defensive_rate: 0.09),
      metrics(silent_failure_rate: 0.011, internal_over_defensive_rate: 0.088),
      metrics(silent_failure_rate: 0.012, internal_over_defensive_rate: 0.087),
      metrics(silent_failure_rate: 0.013, internal_over_defensive_rate: 0.089)
    ]

    right_runs = [
      metrics(silent_failure_rate: 0.04, internal_over_defensive_rate: 0.15),
      metrics(silent_failure_rate: 0.039, internal_over_defensive_rate: 0.152),
      metrics(silent_failure_rate: 0.041, internal_over_defensive_rate: 0.151),
      metrics(silent_failure_rate: 0.038, internal_over_defensive_rate: 0.153)
    ]

    assert {:ok, result} =
             ProfileBenchmark.analyze(:edifice, :fallback, left_runs, right_runs,
               alpha: 0.05,
               iterations: 1_000,
               seed: 456
             )

    silent_failure = Enum.find(result.metric_summaries, &(&1.key == :silent_failure_rate))

    over_defensive =
      Enum.find(result.metric_summaries, &(&1.key == :internal_over_defensive_rate))

    assert silent_failure.winner == :left
    assert over_defensive.winner == :left
  end

  test "analyze returns validation error when required metrics are missing" do
    left_runs = [
      Map.delete(metrics(), :pass_at_1)
    ]

    right_runs = [
      metrics()
    ]

    assert {:error, {:missing_metric, :left, 1, :pass_at_1}} =
             ProfileBenchmark.analyze(:edifice, :fallback, left_runs, right_runs)
  end

  test "write_report writes markdown artifact with backend decision" do
    left_runs = [
      metrics(pass_at_1: 0.78, throughput_tokens_per_sec: 1_450.0),
      metrics(pass_at_1: 0.79, throughput_tokens_per_sec: 1_460.0),
      metrics(pass_at_1: 0.80, throughput_tokens_per_sec: 1_470.0),
      metrics(pass_at_1: 0.81, throughput_tokens_per_sec: 1_480.0)
    ]

    right_runs = [
      metrics(pass_at_1: 0.72, throughput_tokens_per_sec: 1_120.0),
      metrics(pass_at_1: 0.71, throughput_tokens_per_sec: 1_125.0),
      metrics(pass_at_1: 0.73, throughput_tokens_per_sec: 1_130.0),
      metrics(pass_at_1: 0.70, throughput_tokens_per_sec: 1_110.0)
    ]

    assert {:ok, result} =
             ProfileBenchmark.analyze(:edifice, :fallback, left_runs, right_runs,
               alpha: 0.05,
               iterations: 1_000,
               seed: 789
             )

    output_dir = tmp_dir("profile-benchmark-report")
    timestamp = "20260226T030000Z"

    assert {:ok, report_path} =
             ProfileBenchmark.write_report(result, output_dir: output_dir, timestamp: timestamp)

    assert report_path ==
             Path.join(
               output_dir,
               "training-profile-benchmark-edifice-vs-fallback-#{timestamp}.md"
             )

    assert File.exists?(report_path)
    content = File.read!(report_path)

    assert content =~ "# Training Profile Benchmark"
    assert content =~ "Selected profile: `edifice`"
    assert content =~ "Selected backend: `edifice`"
    assert content =~ "| Metric | Direction | Left Mean | Right Mean |"
  end

  defp metrics(overrides \\ []) do
    base = %{
      boundary_under_handling_rate: 0.11,
      convergence_steps: 920.0,
      internal_over_defensive_rate: 0.12,
      pass_at_1: 0.74,
      policy_compliance_f1: 0.80,
      silent_failure_rate: 0.03,
      throughput_tokens_per_sec: 1_200.0
    }

    Enum.into(overrides, base)
  end

  defp tmp_dir(prefix) do
    dir = Path.join(System.tmp_dir!(), "#{prefix}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    dir
  end
end
