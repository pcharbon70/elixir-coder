defmodule ElixirCoder.Inference.BackendTest do
  use ExUnit.Case, async: true

  alias ElixirCoder.Inference.Backend

  test "resolve respects checkpoint metadata backend by default" do
    assert {:ok, resolution} =
             Backend.resolve(%{backend: :custom})

    assert resolution.backend == :custom
    assert resolution.requested_backend == :custom
    assert resolution.policy_mode == :warn
  end

  test "resolve falls back when requested backend misses required features" do
    assert {:ok, resolution} =
             Backend.resolve(%{}, required_features: [:legacy_attention])

    assert resolution.backend == :custom
    assert resolution.requested_backend == :edifice
    assert resolution.fallback?
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
end
