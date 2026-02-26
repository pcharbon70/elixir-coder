defmodule ElixirCoder.Inference.PolicyMonitorTest do
  use ExUnit.Case, async: false

  alias ElixirCoder.Inference.PolicyMonitor

  setup do
    PolicyMonitor.reset!()
    :ok
  end

  test "snapshot aggregates policy metrics overall and by backend" do
    PolicyMonitor.record(
      %{
        count: 1,
        internal_over_defensive_rate: 1,
        boundary_under_handling_rate: 0,
        silent_failure_rate: 1,
        policy_compliant: 0,
        violation_count: 2
      },
      %{backend: :edifice}
    )

    PolicyMonitor.record(
      %{
        count: 1,
        internal_over_defensive_rate: 0,
        boundary_under_handling_rate: 1,
        silent_failure_rate: 0,
        policy_compliant: 1,
        violation_count: 1
      },
      %{backend: "custom"}
    )

    snapshot = PolicyMonitor.snapshot()

    assert snapshot[:count] == 2
    assert_in_delta snapshot[:internal_over_defensive_rate], 0.5, 1.0e-6
    assert_in_delta snapshot[:boundary_under_handling_rate], 0.5, 1.0e-6
    assert_in_delta snapshot[:silent_failure_rate], 0.5, 1.0e-6
    assert_in_delta snapshot[:policy_compliance_rate], 0.5, 1.0e-6
    assert_in_delta snapshot[:average_violation_count], 1.5, 1.0e-6

    assert snapshot[:by_backend][:edifice][:count] == 1
    assert snapshot[:by_backend][:custom][:count] == 1
    assert snapshot[:by_backend][:edifice][:internal_over_defensive_rate] == 1.0
    assert snapshot[:by_backend][:custom][:boundary_under_handling_rate] == 1.0
  end

  test "check_alerts emits telemetry for exceeded thresholds" do
    events = PolicyMonitor.telemetry_event_names()
    handler_id = handler_id("alert")

    :ok =
      :telemetry.attach(
        handler_id,
        events.alert,
        &__MODULE__.handle_telemetry_event/4,
        %{test_pid: self()}
      )

    on_exit(fn ->
      :telemetry.detach(handler_id)
    end)

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
      PolicyMonitor.check_alerts(
        internal_over_defensive_rate: 0.20,
        boundary_under_handling_rate: 1.0,
        silent_failure_rate: 1.0
      )

    assert length(alerts) == 1
    assert hd(alerts).metric == :internal_over_defensive_rate
    assert hd(alerts).severity == :warn

    assert_receive {:telemetry_event, event_name, measurements, metadata}
    assert event_name == events.alert
    assert measurements.count == 1
    assert Enum.any?(metadata.alerts, &(&1.metric == :internal_over_defensive_rate))
    assert metadata.snapshot.count == 1
  end

  @doc false
  def handle_telemetry_event(event, measurements, metadata, %{test_pid: test_pid}) do
    send(test_pid, {:telemetry_event, event, measurements, metadata})
  end

  defp handler_id(suffix) do
    "policy-monitor-test-#{suffix}-#{System.unique_integer([:positive])}"
  end
end
