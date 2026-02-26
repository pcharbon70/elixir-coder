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
    assert result.request_metadata.backend == :edifice
    assert result.request_metadata.requested_backend == :edifice
    assert result.request_metadata.checkpoint_backend == :edifice
    assert result.request_metadata.required_features == [:inference_generation]
  end

  test "apply_adapter uses adapter_injection requirement" do
    adapter = %{name: :exunit, rank: 4}

    assert {:ok, result} = Backend.apply_adapter(:model_state, adapter, backend: :edifice)

    assert result.backend == :edifice
    assert result.adapter == adapter
    assert result.request_metadata.backend == :edifice
    assert result.request_metadata.requested_backend == :edifice
    assert result.request_metadata.required_features == [:adapter_injection]
  end

  test "generate_step response schema is identical across backend paths" do
    generation_state = %{checkpoint_metadata: %{backend: :edifice}}

    assert {:ok, edifice_result} =
             Backend.generate_step(:model_state, %{tokens: [1, 2, 3]}, generation_state)

    assert {:ok, fallback_result} =
             Backend.generate_step(
               :model_state,
               %{tokens: [1, 2, 3]},
               generation_state,
               required_features: [:legacy_attention]
             )

    assert map_keys(edifice_result) == map_keys(fallback_result)
    assert map_keys(edifice_result.request_metadata) == map_keys(fallback_result.request_metadata)
    assert edifice_result.request_metadata.backend == :edifice
    assert fallback_result.request_metadata.backend == :custom
  end

  test "apply_adapter response schema is identical across backend paths" do
    adapter = %{name: :streamdata, rank: 8}

    assert {:ok, edifice_result} =
             Backend.apply_adapter(:model_state, adapter, backend: :edifice)

    assert {:ok, fallback_result} =
             Backend.apply_adapter(:model_state, adapter, backend: :custom)

    assert map_keys(edifice_result) == map_keys(fallback_result)
    assert map_keys(edifice_result.request_metadata) == map_keys(fallback_result.request_metadata)
    assert edifice_result.request_metadata.backend == :edifice
    assert fallback_result.request_metadata.backend == :custom
  end

  test "generate_step propagates backend mismatch enforce error" do
    generation_state = %{checkpoint_metadata: %{"backend" => "custom"}}

    assert {:error, {:backend_mismatch, details}} =
             Backend.generate_step(
               :model_state,
               %{tokens: [1, 2, 3]},
               generation_state,
               backend: :edifice,
               backend_mismatch_mode: :enforce
             )

    assert details.checkpoint_backend == :custom
    assert details.runtime_backend == :edifice
  end

  test "evaluate_candidate returns warn-mode policy warnings with request metadata" do
    generation_state = %{checkpoint_metadata: %{backend: :edifice}}

    code = """
    def handle_cast(msg, state) do
      try do
        process(msg, state)
      rescue
        _ -> :ok
      end
    end
    """

    assert {:ok, result} =
             Backend.evaluate_candidate(
               "Implement handle_cast in GenServer process",
               code,
               generation_state,
               policy_mode: :warn,
               context: :supervised_internal
             )

    assert result.backend == :edifice
    assert result.policy_mode == :warn
    assert result.context == :supervised_internal
    assert result.warnings != []
    assert result.policy_report.compliant? == false
    assert result.request_metadata.backend == :edifice

    assert result.request_metadata.required_features == [
             :inference_generation,
             :policy_enforcement
           ]
  end

  test "evaluate_candidate blocks non-compliant output in enforce mode" do
    generation_state = %{checkpoint_metadata: %{backend: :edifice}}

    code = """
    def create(params) do
      payload = Jason.decode!(params["payload"])
      raise "invalid"
      {:ok, payload}
    end
    """

    assert {:error, {:policy_violations, report}} =
             Backend.evaluate_candidate(
               "Implement API boundary handling",
               code,
               generation_state,
               policy_mode: :enforce,
               context: :boundary_handling
             )

    refute report.compliant?
  end

  test "evaluate_candidate warn-mode schema is consistent across backend paths" do
    generation_state = %{checkpoint_metadata: %{backend: :edifice}}

    code = """
    def create(params) do
      payload = Jason.decode!(params["payload"])
      {:ok, payload}
    end
    """

    assert {:ok, edifice_result} =
             Backend.evaluate_candidate(
               "Handle API boundary request params",
               code,
               generation_state,
               backend: :edifice,
               policy_mode: :warn,
               context: :boundary_handling
             )

    assert {:ok, fallback_result} =
             Backend.evaluate_candidate(
               "Handle API boundary request params",
               code,
               generation_state,
               backend: :custom,
               policy_mode: :warn,
               context: :boundary_handling
             )

    assert map_keys(edifice_result) == map_keys(fallback_result)
    assert map_keys(edifice_result.request_metadata) == map_keys(fallback_result.request_metadata)
    assert edifice_result.request_metadata.backend == :edifice
    assert fallback_result.request_metadata.backend == :custom
  end

  defp map_keys(map) do
    map
    |> Map.keys()
    |> Enum.sort()
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
