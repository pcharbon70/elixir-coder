defmodule ElixirCoder.Backend.ResolverTest do
  use ExUnit.Case, async: true

  alias ElixirCoder.Backend.Resolver

  test "resolves requested backend when required features are supported" do
    assert {:ok, :edifice, metadata} =
             Resolver.resolve(:edifice, [:optimizer, :schedule])

    refute metadata.fallback?
    assert metadata.requested_backend == :edifice
    assert metadata.missing_features == []
  end

  test "falls back to custom when requested backend is missing features" do
    assert {:ok, :custom, metadata} =
             Resolver.resolve(:edifice, [:legacy_attention])

    assert metadata.fallback?
    assert metadata.requested_backend == :edifice
    assert metadata.missing_features == [:legacy_attention]
  end

  test "returns unsupported_features when neither backend supports feature set" do
    assert {:error, {:unsupported_features, details}} =
             Resolver.resolve(:edifice, [:unknown_feature])

    assert details.requested_backend == :edifice
    assert :unknown_feature in details.missing_features
    assert :unknown_feature in details.fallback_missing_features
  end
end
