defmodule Mix.Tasks.Training.Profiles.Compare do
  @shortdoc "Compare two training profiles and write a markdown report"

  @moduledoc """
  Compares two training profiles and writes a comparison report.

      mix training.profiles.compare edifice fallback
      mix training.profiles.compare edifice fallback --output-dir data/reports
      mix training.profiles.compare edifice fallback --require-comparable
  """

  use Mix.Task

  alias ElixirCoder.Training.ProfileRunner
  alias ElixirCoder.Training.Profiles

  @requirements ["app.config"]

  @switches [
    output_dir: :string,
    timestamp: :string,
    require_comparable: :boolean
  ]

  @usage """
  Usage:
    mix training.profiles.compare <left_profile> <right_profile> [options]

  Options:
    --output-dir <dir>         Directory for generated report artifact
    --timestamp <value>        Timestamp suffix for artifact filenames
    --require-comparable       Fail if profile pair is not comparable
  """

  @impl Mix.Task
  def run(args) do
    {opts, positional, invalid} = OptionParser.parse(args, strict: @switches)
    validate_options!(invalid)

    case positional do
      [left_arg, right_arg] ->
        left = parse_profile!(left_arg)
        right = parse_profile!(right_arg)

        case ProfileRunner.write_pair_report(left, right, task_opts(opts)) do
          {:ok, path, prepared_pair} ->
            Mix.shell().info("comparison report: #{path}")
            Mix.shell().info("comparable?: #{prepared_pair.comparison.comparable?}")

            Mix.shell().info(
              "resolved backends: #{left}=#{prepared_pair.left.resolution.backend}, " <>
                "#{right}=#{prepared_pair.right.resolution.backend}"
            )

          {:error, reason} ->
            Mix.raise("failed to compare profiles: #{inspect(reason)}")
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

    require_comparable = [require_comparable?: Keyword.get(opts, :require_comparable, false)]

    output_dir ++ timestamp ++ require_comparable
  end
end
