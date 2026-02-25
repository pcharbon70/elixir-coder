defmodule ElixirCoder.Model.BackendTest do
  use ExUnit.Case, async: true

  alias ElixirCoder.Model.Backend

  test "build_encoder_decoder defaults to Edifice backend" do
    assert {:ok, descriptor} =
             Backend.build_encoder_decoder(%{hidden_size: 768})

    assert descriptor.backend == :edifice
    assert descriptor.builder == Edifice.Blocks.ModelBuilder
    refute descriptor.fallback?
  end

  test "build_encoder_decoder falls back when requested features are unsupported" do
    assert {:ok, descriptor} =
             Backend.build_encoder_decoder(%{}, required_features: [:legacy_attention])

    assert descriptor.backend == :custom
    assert descriptor.builder == ElixirCoder.Model.CustomBuilder
    assert descriptor.fallback?
  end

  test "build_encoder_decoder returns error for unsupported feature sets" do
    assert {:error, {:unsupported_features, details}} =
             Backend.build_encoder_decoder(%{}, required_features: [:unknown_feature])

    assert :unknown_feature in details.missing_features
  end
end
