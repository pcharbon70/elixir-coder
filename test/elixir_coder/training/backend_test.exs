defmodule ElixirCoder.Training.BackendTest do
  use ExUnit.Case, async: true

  alias ElixirCoder.Training.Backend

  test "optimizer uses Edifice provider by default" do
    assert {:ok, descriptor} =
             Backend.optimizer(%{learning_rate: 3.0e-4})

    assert descriptor.backend == :edifice
    assert descriptor.provider == :edifice
    refute descriptor.fallback?
  end

  test "optimizer falls back when required features are unavailable in Edifice" do
    assert {:ok, descriptor} =
             Backend.optimizer(%{}, required_features: [:legacy_attention])

    assert descriptor.backend == :custom
    assert descriptor.provider == :polaris
    assert descriptor.fallback?
  end

  test "peft returns unsupported error when feature set is unsupported everywhere" do
    assert {:error, {:unsupported_features, details}} =
             Backend.peft(%{}, required_features: [:unknown_feature])

    assert :unknown_feature in details.missing_features
    assert :unknown_feature in details.fallback_missing_features
  end
end
