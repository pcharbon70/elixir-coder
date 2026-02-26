defmodule ElixirCoder.Training.ProfileRunnerTest do
  use ExUnit.Case, async: true

  alias ElixirCoder.Training.ProfileRunner

  test "prepare_profile resolves runtime data for edifice profile" do
    assert {:ok, prepared} = ProfileRunner.prepare_profile(:edifice)

    assert prepared.profile_name == :edifice
    assert prepared.runtime_overrides[:requested_backend] == :edifice
    assert prepared.runtime_overrides[:fallback_backend] == :custom
    assert prepared.seed == 42

    assert prepared.resolution.backend == :edifice
    refute prepared.resolution.metadata.fallback?
    assert :model_blocks in prepared.resolution.capabilities
  end

  test "prepare_profile resolves runtime data for fallback profile" do
    assert {:ok, prepared} = ProfileRunner.prepare_profile(:fallback)

    assert prepared.profile_name == :fallback
    assert prepared.runtime_overrides[:requested_backend] == :custom
    refute prepared.runtime_overrides[:allow_fallback?]
    assert prepared.resolution.backend == :custom
    refute prepared.resolution.metadata.fallback?
  end

  test "prepare_profile returns profile not found for unknown profile" do
    assert {:error, {:profile_not_found, :does_not_exist}} =
             ProfileRunner.prepare_profile(:does_not_exist)
  end

  test "prepare_pair returns resolved profiles and comparison" do
    assert {:ok, prepared_pair} = ProfileRunner.prepare_pair(:edifice, :fallback)

    assert prepared_pair.comparison.comparable?
    assert prepared_pair.left.profile_name == :edifice
    assert prepared_pair.right.profile_name == :fallback
  end

  test "write_pair_report creates comparison report and returns prepared pair" do
    output_dir = tmp_dir("profile-runner-pair-report")
    timestamp = "20260226T013000Z"

    assert {:ok, path, prepared_pair} =
             ProfileRunner.write_pair_report(:edifice, :fallback,
               output_dir: output_dir,
               timestamp: timestamp,
               require_comparable?: true
             )

    assert path ==
             Path.join(
               output_dir,
               "training-profile-comparison-edifice-vs-fallback-#{timestamp}.md"
             )

    assert File.exists?(path)
    assert prepared_pair.comparison.comparable?

    content = File.read!(path)
    assert content =~ "# Training Profile Comparison"
    assert content =~ "Left profile: `edifice`"
  end

  test "write_manifest creates deterministic json artifact" do
    output_dir = tmp_dir("profile-runner-manifest")
    timestamp = "20260226T013001Z"

    assert {:ok, path, manifest} =
             ProfileRunner.write_manifest(:edifice,
               output_dir: output_dir,
               timestamp: timestamp
             )

    assert path == Path.join(output_dir, "training-profile-manifest-edifice-#{timestamp}.json")
    assert File.exists?(path)

    assert manifest.profile == :edifice
    assert manifest.backend == :edifice
    assert manifest.requested_backend == :edifice
    assert manifest.fallback_backend == :custom
    assert manifest.fallback? == false
    assert is_map(manifest.objective_weights)

    json = Jason.decode!(File.read!(path))
    assert json["profile"] == "edifice"
    assert json["backend"] == "edifice"
    assert json["requested_backend"] == "edifice"
    assert json["fallback?"] == false
    assert is_map(json["objective_weights"])
  end

  defp tmp_dir(prefix) do
    dir = Path.join(System.tmp_dir!(), "#{prefix}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    dir
  end
end
