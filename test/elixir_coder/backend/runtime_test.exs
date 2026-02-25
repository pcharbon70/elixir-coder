defmodule ElixirCoder.Backend.RuntimeTest do
  use ExUnit.Case, async: false

  alias ElixirCoder.Backend.Runtime

  @persistent_key {Runtime, :active_resolution}

  setup do
    clear_persistent_key()

    on_exit(fn ->
      clear_persistent_key()
    end)

    :ok
  end

  test "config returns runtime defaults from application env" do
    cfg = Runtime.config()

    assert cfg.requested_backend == :edifice
    assert cfg.fallback_backend == :custom
    assert cfg.allow_fallback?
    assert :model_blocks in cfg.required_features
    assert :inference_generation in cfg.required_features
  end

  test "resolve can return fallback backend when requested backend lacks a feature" do
    assert {:ok, resolution} = Runtime.resolve(required_features: [:legacy_attention])

    assert resolution.backend == :custom
    assert resolution.metadata.fallback?
    assert resolution.metadata.requested_backend == :edifice
  end

  test "resolve returns error when fallback is disabled and requested backend lacks a feature" do
    assert {:error, {:unsupported_features, details}} =
             Runtime.resolve(required_features: [:legacy_attention], allow_fallback?: false)

    assert details.requested_backend == :edifice
    assert :legacy_attention in details.missing_features
  end

  test "initialize! persists active resolution" do
    assert resolution = Runtime.initialize!(required_features: [:legacy_attention])

    assert resolution.backend == :custom
    assert Runtime.active_backend() == :custom
    assert Runtime.active_resolution().backend == :custom
  end

  test "initialize! raises for unsupported feature set" do
    assert_raise ArgumentError, ~r/backend resolution failed/, fn ->
      Runtime.initialize!(
        required_features: [:unknown_feature],
        allow_fallback?: false
      )
    end
  end

  defp clear_persistent_key do
    case :persistent_term.get(@persistent_key, :undefined) do
      :undefined -> :ok
      _ -> :persistent_term.erase(@persistent_key)
    end
  end
end
