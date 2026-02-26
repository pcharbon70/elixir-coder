defmodule Mix.Tasks.Training.Profiles.Manifest do
  @shortdoc "Write a runtime manifest for a training profile"

  @moduledoc """
  Resolves runtime backend selection for a training profile and writes a JSON
  manifest artifact.

      mix training.profiles.manifest edifice
      mix training.profiles.manifest fallback --output-dir data/reports
      mix training.profiles.manifest edifice --timestamp 20260226T013000Z
  """

  use Mix.Task

  alias ElixirCoder.Training.ProfileRunner
  alias ElixirCoder.Training.Profiles

  @requirements ["app.config"]

  @switches [
    output_dir: :string,
    timestamp: :string
  ]

  @usage """
  Usage:
    mix training.profiles.manifest <profile> [options]

  Options:
    --output-dir <dir>         Directory for generated manifest artifact
    --timestamp <value>        Timestamp suffix for artifact filename
  """

  @impl Mix.Task
  def run(args) do
    {opts, positional, invalid} = OptionParser.parse(args, strict: @switches)
    validate_options!(invalid)

    case positional do
      [profile_arg] ->
        profile = parse_profile!(profile_arg)

        case ProfileRunner.write_manifest(profile, task_opts(opts)) do
          {:ok, path, manifest} ->
            Mix.shell().info("profile manifest: #{path}")
            Mix.shell().info("profile: #{manifest.profile}")

            Mix.shell().info(
              "resolved backend: #{manifest.backend} (requested=#{manifest.requested_backend})"
            )

            Mix.shell().info("fallback?: #{manifest.fallback?}")

          {:error, reason} ->
            Mix.raise("failed to write profile manifest: #{inspect(reason)}")
        end

      _other ->
        Mix.raise(@usage)
    end
  end

  defp validate_options!([]), do: :ok

  defp validate_options!(invalid) do
    invalid_text =
      Enum.map_join(invalid, ", ", fn
        {key, nil} -> "--#{key}"
        {key, value} -> "--#{key}=#{value}"
      end)

    Mix.raise("invalid options: #{invalid_text}\n\n#{@usage}")
  end

  defp parse_profile!(name) do
    available = Profiles.available_profiles()

    case Enum.find(available, &(Atom.to_string(&1) == name)) do
      nil ->
        Mix.raise("unknown profile #{inspect(name)}. Available: #{Enum.join(available, ", ")}")

      profile ->
        profile
    end
  end

  defp task_opts(opts) do
    output_dir =
      case opts[:output_dir] do
        nil -> []
        dir -> [output_dir: Path.expand(dir, File.cwd!())]
      end

    timestamp =
      case opts[:timestamp] do
        nil -> []
        value -> [timestamp: value]
      end

    output_dir ++ timestamp
  end
end
