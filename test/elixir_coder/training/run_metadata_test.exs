defmodule ElixirCoder.Training.RunMetadataTest do
  use ExUnit.Case, async: false

  alias ElixirCoder.Training.RunMetadata

  test "from_profile builds backend-aware checkpoint metadata" do
    assert {:ok, metadata} =
             RunMetadata.from_profile(:edifice,
               run_id: "run-edifice-test",
               generated_at: "2026-02-26T03:30:00Z"
             )

    assert metadata.profile == :edifice
    assert metadata.backend == :edifice
    assert metadata.requested_backend == :edifice
    assert metadata.fallback_backend == :custom
    assert metadata.fallback? == false
    assert metadata.run_id == "run-edifice-test"
    assert metadata.generated_at == "2026-02-26T03:30:00Z"
    assert is_list(metadata.capabilities)
    assert :model_blocks in metadata.capabilities
  end

  test "write and read roundtrip persists checkpoint metadata json" do
    output_dir = tmp_dir("run-metadata")

    assert {:ok, metadata} =
             RunMetadata.from_profile(:fallback,
               run_id: "run-fallback-test",
               generated_at: "2026-02-26T03:31:00Z"
             )

    assert {:ok, path} = RunMetadata.write(metadata, output_dir)
    assert path == Path.join(output_dir, "checkpoint-metadata.json")
    assert File.exists?(path)

    assert {:ok, loaded} = RunMetadata.read(path)
    assert loaded["profile"] == "fallback"
    assert loaded["backend"] == "custom"
    assert loaded["requested_backend"] == "custom"
    assert loaded["run_id"] == "run-fallback-test"
  end

  test "emit_metric adds backend labels to telemetry metadata" do
    handler_id = handler_id("metric")
    events = RunMetadata.telemetry_event_names()
    attach_handler!(handler_id, events.metric)

    on_exit(fn ->
      :telemetry.detach(handler_id)
    end)

    assert {:ok, metadata} =
             RunMetadata.from_profile(:edifice,
               run_id: "run-telemetry-metric",
               generated_at: "2026-02-26T03:32:00Z"
             )

    assert :ok =
             RunMetadata.emit_metric(:pass_at_1, 0.77, metadata, %{epoch: 3, split: :validation})

    assert_receive {:telemetry_event, event_name, measurements, event_metadata}
    assert event_name == events.metric
    assert measurements.count == 1
    assert measurements.value == 0.77
    assert event_metadata.metric == :pass_at_1
    assert event_metadata.backend == :edifice
    assert event_metadata.requested_backend == :edifice
    assert event_metadata.profile == :edifice
    assert event_metadata.run_id == "run-telemetry-metric"
    assert event_metadata.epoch == 3
    assert event_metadata.split == :validation
  end

  test "check_runtime_backend emits warn on mismatch in warn mode" do
    handler_id = handler_id("backend-warn")
    events = RunMetadata.telemetry_event_names()
    attach_handler!(handler_id, events.backend_mismatch)

    on_exit(fn ->
      :telemetry.detach(handler_id)
    end)

    checkpoint_metadata = %{
      "backend" => "edifice",
      "profile" => "edifice",
      "requested_backend" => "edifice",
      "run_id" => "run-backend-warn"
    }

    assert {:warn, details} =
             RunMetadata.check_runtime_backend(checkpoint_metadata,
               runtime_backend: :custom,
               mode: :warn
             )

    assert details.checkpoint_backend == :edifice
    assert details.runtime_backend == :custom
    assert details.mode == :warn

    assert_receive {:telemetry_event, event_name, measurements, event_metadata}
    assert event_name == events.backend_mismatch
    assert measurements.count == 1
    assert event_metadata.checkpoint_backend == :edifice
    assert event_metadata.runtime_backend == :custom
  end

  test "check_runtime_backend enforces mismatch when configured" do
    checkpoint_metadata = %{
      "backend" => "edifice",
      "profile" => "edifice",
      "requested_backend" => "edifice",
      "run_id" => "run-backend-enforce"
    }

    assert {:error, details} =
             RunMetadata.check_runtime_backend(checkpoint_metadata,
               runtime_backend: :custom,
               mode: :enforce
             )

    assert details.checkpoint_backend == :edifice
    assert details.runtime_backend == :custom
    assert details.mode == :enforce
  end

  test "check_runtime_backend returns :ok when backends match" do
    checkpoint_metadata = %{
      "backend" => "edifice",
      "profile" => "edifice",
      "requested_backend" => "edifice",
      "run_id" => "run-backend-ok"
    }

    assert :ok =
             RunMetadata.check_runtime_backend(checkpoint_metadata,
               runtime_backend: :edifice,
               mode: :enforce
             )
  end

  defp tmp_dir(prefix) do
    dir = Path.join(System.tmp_dir!(), "#{prefix}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    dir
  end

  defp handler_id(suffix) do
    "run-metadata-test-#{suffix}-#{System.unique_integer([:positive])}"
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
