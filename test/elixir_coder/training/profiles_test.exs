defmodule ElixirCoder.Training.ProfilesTest do
  use ExUnit.Case, async: true

  alias ElixirCoder.Training.Profiles

  test "available_profiles includes edifice and fallback" do
    assert :edifice in Profiles.available_profiles()
    assert :fallback in Profiles.available_profiles()
  end

  test "loads edifice profile with expected backend settings" do
    assert {:ok, profile} = Profiles.load(:edifice)

    assert profile[:profile] == :edifice
    assert profile[:backend] == :edifice
    assert profile[:fallback_backend] == :custom
    assert profile[:allow_fallback?]
    assert is_list(profile[:required_features])
    assert :model_blocks in profile[:required_features]
  end

  test "loads fallback profile with deterministic backend settings" do
    assert {:ok, profile} = Profiles.load(:fallback)

    assert profile[:profile] == :fallback
    assert profile[:backend] == :custom
    assert profile[:fallback_backend] == :custom
    refute profile[:allow_fallback?]
  end

  test "runtime_overrides maps profile fields to runtime options" do
    assert {:ok, overrides} = Profiles.runtime_overrides(:edifice)

    assert overrides[:requested_backend] == :edifice
    assert overrides[:fallback_backend] == :custom
    assert overrides[:allow_fallback?]
    assert is_list(overrides[:required_features])
  end

  test "compare highlights backend-related difference keys" do
    assert {:ok, comparison} = Profiles.compare(:edifice, :fallback)

    assert :backend in comparison.differing_keys
    assert :allow_fallback? in comparison.differing_keys
    assert :profile in comparison.differing_keys
  end

  test "load returns error for unknown profile" do
    assert {:error, {:profile_not_found, :does_not_exist}} = Profiles.load(:does_not_exist)
  end
end
