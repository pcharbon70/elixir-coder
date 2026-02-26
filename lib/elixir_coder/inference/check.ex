defmodule ElixirCoder.Inference.Check do
  @moduledoc """
  Inference-time candidate checks for syntax, quality, and security.

  This module provides local heuristic defaults plus callback hooks for
  integrating Credo/Sobelow in later phases.
  """

  @type check_issue :: %{
          code: atom() | nil,
          line: non_neg_integer() | nil,
          message: String.t(),
          severity: :warning | :error,
          source: :quality | :security | :syntax
        }

  @type syntax_error :: %{
          description: String.t(),
          line: non_neg_integer() | nil,
          source: :syntax
        }

  @spec check_syntax(String.t()) :: {:ok, Macro.t()} | {:error, syntax_error()}
  def check_syntax(code) when is_binary(code) do
    case Code.string_to_quoted(code) do
      {:ok, ast} ->
        {:ok, ast}

      {:error, {line, _error, description}} ->
        {:error,
         %{
           description: to_string(description),
           line: normalize_line(line),
           source: :syntax
         }}
    end
  end

  @spec check_quality(String.t(), keyword()) :: {:ok, String.t()} | {:error, [check_issue()]}
  def check_quality(code, opts \\ []) when is_binary(code) and is_list(opts) do
    case Keyword.get(opts, :quality_checker) do
      checker when is_function(checker, 1) ->
        run_external_checker(code, checker, :quality)

      nil ->
        issues = heuristic_quality_issues(code)
        if issues == [], do: {:ok, code}, else: {:error, issues}

      other ->
        {:error,
         [
           %{
             code: nil,
             line: nil,
             message: "invalid quality checker: #{inspect(other)}",
             severity: :error,
             source: :quality
           }
         ]}
    end
  end

  @spec check_security(String.t(), keyword()) :: {:ok, String.t()} | {:error, [check_issue()]}
  def check_security(code, opts \\ []) when is_binary(code) and is_list(opts) do
    case Keyword.get(opts, :security_checker) do
      checker when is_function(checker, 1) ->
        run_external_checker(code, checker, :security)

      nil ->
        issues = heuristic_security_issues(code)
        if issues == [], do: {:ok, code}, else: {:error, issues}

      other ->
        {:error,
         [
           %{
             code: nil,
             line: nil,
             message: "invalid security checker: #{inspect(other)}",
             severity: :error,
             source: :security
           }
         ]}
    end
  end

  defp run_external_checker(code, checker, source) do
    case checker.(code) do
      :ok ->
        {:ok, code}

      {:ok, []} ->
        {:ok, code}

      {:ok, issues} when is_list(issues) ->
        normalized = normalize_issues(issues, source)
        if normalized == [], do: {:ok, code}, else: {:error, normalized}

      {:error, issues} when is_list(issues) ->
        {:error, normalize_issues(issues, source)}

      other when is_list(other) ->
        normalized = normalize_issues(other, source)
        if normalized == [], do: {:ok, code}, else: {:error, normalized}

      other ->
        {:error,
         [
           %{
             code: nil,
             line: nil,
             message: "invalid checker result: #{inspect(other)}",
             severity: :error,
             source: source
           }
         ]}
    end
  end

  defp normalize_issues(issues, source) do
    issues
    |> Enum.map(&normalize_issue(&1, source))
  end

  defp normalize_issue(%{message: message} = issue, source) do
    %{
      code: Map.get(issue, :code),
      line: normalize_line(Map.get(issue, :line)),
      message: to_string(message),
      severity: normalize_severity(Map.get(issue, :severity)),
      source: source
    }
  end

  defp normalize_issue(issue, source) when is_binary(issue) do
    %{
      code: nil,
      line: nil,
      message: issue,
      severity: :warning,
      source: source
    }
  end

  defp normalize_issue(issue, source) do
    %{
      code: nil,
      line: nil,
      message: inspect(issue),
      severity: :warning,
      source: source
    }
  end

  defp heuristic_quality_issues(code) do
    []
    |> maybe_add_quality_issue(
      String.contains?(code, "IO.inspect("),
      :io_inspect,
      "Avoid IO.inspect/1 in generated production code."
    )
    |> maybe_add_quality_issue(
      String.contains?(code, "try do") and String.contains?(code, "rescue"),
      :broad_try_rescue,
      "Broad try/rescue detected; prefer explicit control flow."
    )
  end

  defp heuristic_security_issues(code) do
    []
    |> maybe_add_security_issue(
      String.contains?(code, "System.cmd("),
      :system_cmd,
      "Use of System.cmd/3 requires strict input validation."
    )
    |> maybe_add_security_issue(
      String.contains?(code, "Code.eval_string("),
      :code_eval_string,
      "Dynamic evaluation via Code.eval_string/1 is unsafe for untrusted input."
    )
  end

  defp maybe_add_quality_issue(issues, true, code, message) do
    [%{code: code, line: nil, message: message, severity: :warning, source: :quality} | issues]
  end

  defp maybe_add_quality_issue(issues, false, _code, _message), do: issues

  defp maybe_add_security_issue(issues, true, code, message) do
    [%{code: code, line: nil, message: message, severity: :error, source: :security} | issues]
  end

  defp maybe_add_security_issue(issues, false, _code, _message), do: issues

  defp normalize_severity(:error), do: :error
  defp normalize_severity(_other), do: :warning

  defp normalize_line(line) when is_integer(line) and line >= 0, do: line
  defp normalize_line(_line), do: nil
end
