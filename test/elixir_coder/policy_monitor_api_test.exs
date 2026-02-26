defmodule ElixirCoder.PolicyMonitorApiTest do
  use ExUnit.Case, async: false

  alias ElixirCoder.Inference.PolicyMonitor

  setup do
    PolicyMonitor.reset!()
    :ok
  end

  test "policy_monitor_snapshot exposes current aggregate metrics" do
    snapshot = ElixirCoder.policy_monitor_snapshot()

    assert snapshot.count == 0
    assert snapshot.internal_over_defensive_rate == 0.0
    assert snapshot.boundary_under_handling_rate == 0.0
    assert snapshot.silent_failure_rate == 0.0
    assert snapshot.policy_compliance_rate == 0.0
    assert snapshot.average_violation_count == 0.0
  end

  test "policy_monitor_alerts returns warn alerts for exceeded thresholds" do
    PolicyMonitor.record(
      %{
        count: 1,
        internal_over_defensive_rate: 1,
        boundary_under_handling_rate: 0,
        silent_failure_rate: 0,
        policy_compliant: 0,
        violation_count: 1
      },
      %{backend: :edifice}
    )

    alerts =
      ElixirCoder.policy_monitor_alerts(
        internal_over_defensive_rate: 0.10,
        boundary_under_handling_rate: 1.0,
        silent_failure_rate: 1.0
      )

    assert length(alerts) == 1
    assert hd(alerts).metric == :internal_over_defensive_rate
    assert hd(alerts).severity == :warn
  end
end
