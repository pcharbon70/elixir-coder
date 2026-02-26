defmodule ElixirCoder.Inference.Repair do
  @moduledoc """
  Repair prompt generation for failed inference candidates.
  """

  @spec build_prompt(String.t(), String.t(), list(), keyword()) :: String.t()
  def build_prompt(original_prompt, failed_code, issues, opts \\ [])
      when is_binary(original_prompt) and is_binary(failed_code) and is_list(issues) and
             is_list(opts) do
    issue_lines = format_issues(issues)

    policy_section =
      case Keyword.get(opts, :policy_report) do
        %{context: context, violations: violations}
        when is_list(violations) and violations != [] ->
          violations_text =
            Enum.map_join(violations, "\n", fn violation ->
              "- `#{violation.non_compliance_reason}`#{line_suffix(violation.line)}: #{violation.message}"
            end)

          """
          ## Policy Context
          - Context: `#{context}`
          - Violations:
          #{violations_text}
          """

        _other ->
          ""
      end

    """
    You are repairing Elixir code generated from a user request.

    ## Original Request
    #{original_prompt}

    ## Failed Candidate
    ```elixir
    #{failed_code}
    ```

    ## Detected Issues
    #{issue_lines}

    #{policy_section}

    Rewrite the code and fix all listed issues while preserving the requested behavior.
    Return only corrected Elixir code.
    """
  end

  defp format_issues([]), do: "- none"

  defp format_issues(issues) do
    Enum.map_join(issues, "\n", fn issue ->
      source = Map.get(issue, :source, :unknown)
      message = Map.get(issue, :message, inspect(issue))
      code = Map.get(issue, :code)
      line = Map.get(issue, :line)

      "- [#{source}]#{code_suffix(code)}#{line_suffix(line)} #{message}"
    end)
  end

  defp code_suffix(nil), do: ""
  defp code_suffix(code), do: " `#{code}`"

  defp line_suffix(nil), do: ""
  defp line_suffix(line), do: " at line #{line}"
end
