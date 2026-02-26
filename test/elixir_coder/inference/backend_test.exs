defmodule ElixirCoder.Inference.BackendTest do
  use ExUnit.Case, async: false

  alias ElixirCoder.Inference.Backend

  test "resolve respects checkpoint metadata backend by default" do
    assert {:ok, resolution} =
             Backend.resolve(%{backend: :custom})

    assert resolution.backend == :custom
    assert resolution.requested_backend == :custom
    assert resolution.policy_mode == :warn
  end

  test "resolve supports checkpoint metadata loaded from json string keys" do
    assert {:ok, resolution} =
             Backend.resolve(%{"backend" => "custom"})

    assert resolution.backend == :custom
    assert resolution.checkpoint_backend == :custom
    assert resolution.requested_backend == :custom
  end

  test "resolve falls back when requested backend misses required features" do
    assert {:ok, resolution} =
             Backend.resolve(%{}, required_features: [:legacy_attention])

    assert resolution.backend == :custom
    assert resolution.requested_backend == :edifice
    assert resolution.fallback?
  end

  test "resolve emits backend resolved telemetry with decision labels" do
    handler_id = handler_id("resolved")
    events = Backend.telemetry_event_names()
    attach_handler!(handler_id, events.resolved)

    on_exit(fn ->
      :telemetry.detach(handler_id)
    end)

    assert {:ok, resolution} =
             Backend.resolve(%{backend: :edifice}, policy_mode: :warn)

    assert_receive {:telemetry_event, event_name, measurements, metadata}
    assert event_name == events.resolved
    assert measurements.count == 1
    assert measurements.fallback == 0
    assert measurements.mismatch == 0
    assert metadata.backend == resolution.backend
    assert metadata.requested_backend == resolution.requested_backend
    assert metadata.checkpoint_backend == :edifice
    assert metadata.policy_mode == :warn
    assert metadata.mismatch_mode == :warn
  end

  test "resolve emits mismatch telemetry and returns mismatch details in warn mode" do
    handler_id = handler_id("mismatch-warn")
    events = Backend.telemetry_event_names()
    attach_handler!(handler_id, events.mismatch)

    on_exit(fn ->
      :telemetry.detach(handler_id)
    end)

    assert {:ok, resolution} =
             Backend.resolve(
               %{"backend" => "custom", "requested_backend" => "custom"},
               backend: :edifice,
               backend_mismatch_mode: :warn
             )

    assert resolution.backend == :edifice
    assert resolution.mismatch?
    assert resolution.mismatch_mode == :warn
    assert resolution.mismatch_details.checkpoint_backend == :custom
    assert resolution.mismatch_details.runtime_backend == :edifice

    assert_receive {:telemetry_event, event_name, measurements, metadata}
    assert event_name == events.mismatch
    assert measurements.count == 1
    assert metadata.checkpoint_backend == :custom
    assert metadata.runtime_backend == :edifice
    assert metadata.mode == :warn
  end

  test "resolve returns error when mismatch mode is enforce" do
    assert {:error, {:backend_mismatch, details}} =
             Backend.resolve(
               %{"backend" => "custom", "requested_backend" => "custom"},
               backend: :edifice,
               backend_mismatch_mode: :enforce
             )

    assert details.checkpoint_backend == :custom
    assert details.runtime_backend == :edifice
    assert details.mode == :enforce
  end

  test "generate_step resolves backend with inference feature requirement" do
    generation_state = %{checkpoint_metadata: %{backend: :edifice}}

    assert {:ok, result} =
             Backend.generate_step(:model_state, %{tokens: [1, 2, 3]}, generation_state)

    assert result.backend == :edifice
    assert result.generation_state == generation_state
  end

  test "apply_adapter uses adapter_injection requirement" do
    adapter = %{name: :exunit, rank: 4}

    assert {:ok, result} = Backend.apply_adapter(:model_state, adapter, backend: :edifice)

    assert result.backend == :edifice
    assert result.adapter == adapter
  end

  defp handler_id(suffix) do
    "inference-backend-test-#{suffix}-#{System.unique_integer([:positive])}"
  end

  defp attach_handler!(handler_id, event_name) do
    :telemetry.attach(
      handler_id,
      event_name,
      &__MODULE__.handle_telemetry_event/4,
      %{test_pid: self()}
    )
  end

  @doc false
  def handle_telemetry_event(event, measurements, metadata, %{test_pid: test_pid}) do
    send(test_pid, {:telemetry_event, event, measurements, metadata})
  end
end
