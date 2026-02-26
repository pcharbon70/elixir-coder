defmodule Mix.Tasks.Training.Profiles.CheckpointMetadata do
  @shortdoc "Generate checkpoint metadata for a training profile"

  @moduledoc """
  Generates backend-aware checkpoint metadata from a training profile.

      mix training.profiles.checkpoint_metadata edifice
      mix training.profiles.checkpoint_metadata fallback --output-path data/checkpoints/fallback
      mix training.profiles.checkpoint_metadata edifice --run-id run-20260226-01
  """

  use Mix.Task

  alias ElixirCoder.Training.Profiles
  alias ElixirCoder.Training.RunMetadata

  @requirements ["app.config"]

  @switches [
    generated_at: :string,
    output_path: :string,
    run_id: :string
  ]

  @usage """
  Usage:
    mix training.profiles.checkpoint_metadata <profile> [options]

  Options:
    --output-path <path>       Output file path or directory (default: data/checkpoints/<profile>-<run_id>/)
    --run-id <id>              Explicit run identifier
    --generated-at <iso8601>   Explicit generation timestamp
  """

  @impl Mix.Task
  def run(args) do
    {opts, positional, invalid} = OptionParser.parse(args, strict: @switches)
    validate_options!(invalid)

    case positional do
      [profile_arg] ->
        profile = parse_profile!(profile_arg)
        run_metadata_opts = build_run_metadata_opts(opts)

        with {:ok, metadata} <- RunMetadata.from_profile(profile, run_metadata_opts),
             {:ok, output_path} <-
               RunMetadata.write(metadata, resolve_output_path(profile, metadata, opts)) do
          Mix.shell().info("checkpoint metadata: #{output_path}")
          Mix.shell().info("profile: #{metadata.profile}")
          Mix.shell().info("backend: #{metadata.backend}")
          Mix.shell().info("requested_backend: #{metadata.requested_backend}")
          Mix.shell().info("run_id: #{metadata.run_id}")
        else
          {:error, reason} ->
            Mix.raise("failed to generate checkpoint metadata: #{inspect(reason)}")
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

  defp build_run_metadata_opts(opts) do
    run_id =
      case opts[:run_id] do
        nil -> []
        value -> [run_id: value]
      end

    generated_at =
      case opts[:generated_at] do
        nil -> []
        value -> [generated_at: value]
      end

    run_id ++ generated_at
  end

  defp resolve_output_path(profile, metadata, opts) do
    case opts[:output_path] do
      nil ->
        Path.expand("data/checkpoints/#{profile}-#{metadata.run_id}", File.cwd!())

      output_path ->
        Path.expand(output_path, File.cwd!())
    end
  end
end
