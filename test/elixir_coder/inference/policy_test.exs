defmodule ElixirCoder.Inference.PolicyTest do
  use ExUnit.Case, async: true

  alias ElixirCoder.Inference.Policy

  test "classify_context labels OTP callback prompts as supervised_internal" do
    prompt = """
    Implement handle_call for a GenServer that tracks worker state and uses OTP supervision.
    """

    result = Policy.classify_context(prompt)

    assert result.context == :supervised_internal
    assert result.internal_score > result.boundary_score
  end

  test "check_ast flags blanket rescue in supervised_internal context" do
    code = """
    defmodule Worker do
      use GenServer

      def handle_cast(msg, state) do
        try do
          process(msg, state)
        rescue
          _ -> :ok
        end
      end
    end
    """

    assert {:ok, report} = Policy.check_ast(code, context: :supervised_internal)
    refute report.compliant?

    reasons = Enum.map(report.violations, & &1.non_compliance_reason)
    assert :broad_rescue_internal in reasons
    assert :swallowed_exception in reasons
  end

  test "check_ast flags missing expected-error handling at boundary context" do
    code = """
    defmodule ApiController do
      def create(params) do
        amount = String.to_integer(params["amount"])
        payload = Jason.decode!(params["payload"])
        {:ok, %{amount: amount, payload: payload}}
      end
    end
    """

    assert {:ok, report} = Policy.check_ast(code, context: :boundary_handling)
    refute report.compliant?

    assert Enum.any?(
             report.violations,
             &(&1.non_compliance_reason == :missing_boundary_validation)
           )
  end

  test "build_repair_prompt includes context and violations" do
    code = """
    def handle_cast(msg, state) do
      try do
        process(msg, state)
      rescue
        _ -> :ok
      end
    end
    """

    assert {:ok, report} = Policy.check_ast(code, context: :supervised_internal)
    prompt = Policy.build_repair_prompt("Fix worker callback", code, report)

    assert prompt =~ "Context: `supervised_internal`"
    assert prompt =~ "broad_rescue_internal"
    assert prompt =~ "swallowed_exception"
    assert prompt =~ "Fix worker callback"
  end

  test "evaluate_output with policy_mode warn returns warnings without hard failure" do
    code = """
    def handle_call(req, _from, state) do
      try do
        {:reply, process(req), state}
      rescue
        _ -> {:reply, :ok, state}
      end
    end
    """

    assert {:ok, result} =
             Policy.evaluate_output("Implement handle_call for GenServer", code,
               policy_mode: :warn,
               context: :supervised_internal
             )

    assert result.policy_mode == :warn
    assert result.context == :supervised_internal
    assert result.warnings != []
    refute result.policy_report.compliant?
  end

  test "evaluate_output with policy_mode enforce blocks non-compliant output" do
    code = """
    def create(params) do
      payload = Jason.decode!(params["payload"])
      raise "invalid"
      {:ok, payload}
    end
    """

    assert {:error, {:policy_violations, report}} =
             Policy.evaluate_output("Build boundary handler for API request", code,
               policy_mode: :enforce,
               context: :boundary_handling
             )

    refute report.compliant?

    reasons = Enum.map(report.violations, & &1.non_compliance_reason)
    assert :missing_boundary_validation in reasons
    assert :unsafe_raise_boundary in reasons
  end

  test "operational_metrics maps report to per-request policy signals" do
    code = """
    def create(params) do
      payload = Jason.decode!(params["payload"])
      raise "invalid"
      {:ok, payload}
    end
    """

    assert {:ok, report} = Policy.check_ast(code, context: :boundary_handling)
    metrics = Policy.operational_metrics(report)

    assert metrics.policy_compliant == 0
    assert metrics.boundary_under_handling_rate == 1
    assert metrics.internal_over_defensive_rate == 0
    assert metrics.silent_failure_rate == 0
    assert metrics.violation_count >= 1
  end
end
