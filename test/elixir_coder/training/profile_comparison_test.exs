defmodule ElixirCoder.Training.ProfileComparisonTest do
  use ExUnit.Case, async: true

  alias ElixirCoder.Training.ProfileComparison
  alias ElixirCoder.Training.Profiles

  test "compare by profile names returns comparable result for edifice vs fallback" do
    assert {:ok, result} = ProfileComparison.compare(:edifice, :fallback)

    assert result.comparable?
    assert :backend in result.differing_keys
    assert :allow_fallback? in result.differing_keys
    assert result.invariant_failures == []
    assert result.unexpected_differences == []
  end

  test "compare profile maps detects invariant mismatch" do
    edifice = Profiles.load!(:edifice)
    fallback_with_new_seed = Keyword.put(Profiles.load!(:fallback), :seed, 99)

    result = ProfileComparison.compare(edifice, fallback_with_new_seed)

    refute result.comparable?
    assert [%{key: :seed}] = result.invariant_failures
  end

  test "compare profile maps detects unexpected differences" do
    edifice = Profiles.load!(:edifice)
    fallback_with_extra = Keyword.put(Profiles.load!(:fallback), :dataset_mix, [70, 20, 10])

    result = ProfileComparison.compare(edifice, fallback_with_extra)

    refute result.comparable?
    assert :dataset_mix in result.unexpected_differences
  end

  test "write_report creates markdown artifact for profile pair" do
    output_dir = tmp_dir("profile-comparison-report")

    assert {:ok, path, result} =
             ProfileComparison.write_report(:edifice, :fallback,
               output_dir: output_dir,
               timestamp: "20260226T001500Z"
             )

    assert result.comparable?
    assert File.exists?(path)

    content = File.read!(path)
    assert content =~ "# Training Profile Comparison"
    assert content =~ "Left profile: `edifice`"
    assert content =~ "Right profile: `fallback`"
  end

  test "write_report can enforce comparable profile requirement" do
    output_dir = tmp_dir("profile-comparison-enforcement")
    edifice = Profiles.load!(:edifice)
    fallback_with_new_seed = Keyword.put(Profiles.load!(:fallback), :seed, 99)

    assert {:error, {:profiles_not_comparable, comparison}} =
             ProfileComparison.write_report(edifice, fallback_with_new_seed,
               output_dir: output_dir,
               timestamp: "20260226T001501Z",
               require_comparable?: true
             )

    refute comparison.comparable?
  end

  defp tmp_dir(prefix) do
    dir = Path.join(System.tmp_dir!(), "#{prefix}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    dir
  end
end
