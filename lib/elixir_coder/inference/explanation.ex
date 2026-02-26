defmodule ElixirCoder.Inference.Explanation do
  @moduledoc """
  Explanation generation utilities for quality/security issues.

  This module provides a local explanation pipeline:
  - extract issue context from generated code
  - retrieve relevant documentation snippets
  - synthesize a structured explanation
  - format markdown output with concrete fix suggestions
  """

  @type issue :: %{
          code: atom() | String.t() | nil,
          line: non_neg_integer() | nil,
          message: String.t(),
          severity: :warning | :error,
          source: :quality | :security | :syntax | atom()
        }

  @type issue_context :: %{
          code_snippet: String.t(),
          issue: issue(),
          line_range: {non_neg_integer(), non_neg_integer()},
          ontology: map()
        }

  @type doc_snippet :: %{
          context: String.t(),
          source: :credo | :sobelow | :cwe | atom(),
          tags: [atom()],
          title: String.t(),
          url: String.t()
        }

  @type explanation :: %{
          docs: [doc_snippet()],
          fix_example: String.t(),
          how_to_fix: [String.t()],
          issue_type: atom(),
          title: String.t(),
          what: String.t(),
          why: String.t()
        }

  @default_docs [
    %{
      context: "Avoid debugging prints in production code paths.",
      source: :credo,
      tags: [:quality, :io_inspect],
      title: "Credo: Avoid IO.inspect/1 in production code",
      url: "https://hexdocs.pm/credo/readme.html"
    },
    %{
      context: "Command execution must validate and sanitize any external input first.",
      source: :sobelow,
      tags: [:security, :system_cmd],
      title: "Sobelow: Command execution safety",
      url: "https://hexdocs.pm/sobelow/readme.html"
    },
    %{
      context:
        "Improper neutralization of special elements in commands can lead to code execution.",
      source: :cwe,
      tags: [:security, :cwe_78, :system_cmd],
      title: "CWE-78: OS Command Injection",
      url: "https://cwe.mitre.org/data/definitions/78.html"
    },
    %{
      context: "Dynamic eval of untrusted data can result in arbitrary code execution.",
      source: :cwe,
      tags: [:security, :cwe_95, :code_eval_string],
      title: "CWE-95: Eval Injection",
      url: "https://cwe.mitre.org/data/definitions/95.html"
    }
  ]

  @spec extract_context(String.t(), map(), keyword()) :: issue_context()
  def extract_context(code, issue, opts \\ [])
      when is_binary(code) and is_map(issue) and is_list(opts) do
    radius = Keyword.get(opts, :snippet_radius, 2)
    line = normalize_line(Map.get(issue, :line) || Map.get(issue, "line"))
    lines = String.split(code, "\n")
    total_lines = length(lines)

    {start_line, end_line} =
      case line do
        nil ->
          start = 1
          end_line = min(total_lines, max(1, radius * 2 + 1))
          {start, end_line}

        value ->
          start = max(1, value - radius)
          stop = min(total_lines, value + radius)
          {start, stop}
      end

    snippet =
      lines
      |> Enum.slice(max(start_line - 1, 0), max(end_line - start_line + 1, 1))
      |> Enum.join("\n")

    normalized_issue = normalize_issue(issue)

    %{
      code_snippet: snippet,
      issue: normalized_issue,
      line_range: {start_line, end_line},
      ontology: ontology_context(normalized_issue)
    }
  end

  @spec retrieve_docs(map(), keyword()) :: [doc_snippet()]
  def retrieve_docs(issue, opts \\ []) when is_map(issue) and is_list(opts) do
    max_docs = Keyword.get(opts, :max_docs, 3)
    docs_index = Keyword.get(opts, :docs_index, @default_docs)
    normalized_issue = normalize_issue(issue)
    tags = query_tags(normalized_issue)

    docs_index
    |> Enum.filter(fn doc ->
      doc_tags = Map.get(doc, :tags, [])
      Enum.any?(doc_tags, &(&1 in tags))
    end)
    |> Enum.take(max_docs)
  end

  @spec generate(issue_context(), [doc_snippet()], keyword()) :: explanation()
  def generate(issue_context, docs, opts \\ [])
      when is_map(issue_context) and is_list(docs) and is_list(opts) do
    issue = issue_context.issue
    issue_type = issue_type(issue)
    title = "Issue explanation for #{issue_type}"
    {what, why, how_to_fix, fix_example} = explanation_templates(issue, issue_context, docs)

    %{
      docs: docs,
      fix_example: fix_example,
      how_to_fix: how_to_fix,
      issue_type: issue_type,
      title: title,
      what: what,
      why: why
    }
  end

  @spec format_markdown(explanation()) :: String.t()
  def format_markdown(explanation) when is_map(explanation) do
    docs_section =
      case Map.get(explanation, :docs, []) do
        [] ->
          "- none"

        docs ->
          Enum.map_join(docs, "\n", fn doc ->
            "- [#{doc.title}](#{doc.url}) (#{doc.source})"
          end)
      end

    fix_steps =
      explanation
      |> Map.get(:how_to_fix, [])
      |> Enum.map_join("\n", fn step -> "- #{step}" end)

    """
    # #{explanation.title}

    ## What
    #{explanation.what}

    ## Why It Matters
    #{explanation.why}

    ## How To Fix
    #{fix_steps}

    ## References
    #{docs_section}

    ## Example Fix
    ```elixir
    #{explanation.fix_example}
    ```
    """
  end

  @spec explain(String.t(), map(), keyword()) ::
          {:ok,
           %{
             context: issue_context(),
             docs: [doc_snippet()],
             explanation: explanation(),
             markdown: String.t()
           }}
  def explain(code, issue, opts \\ []) when is_binary(code) and is_map(issue) and is_list(opts) do
    context = extract_context(code, issue, opts)
    docs = retrieve_docs(issue, opts)
    explanation = generate(context, docs, opts)
    markdown = format_markdown(explanation)

    {:ok,
     %{
       context: context,
       docs: docs,
       explanation: explanation,
       markdown: markdown
     }}
  end

  defp normalize_issue(issue) do
    %{
      code: normalize_code(Map.get(issue, :code) || Map.get(issue, "code")),
      line: normalize_line(Map.get(issue, :line) || Map.get(issue, "line")),
      message: to_string(Map.get(issue, :message) || Map.get(issue, "message") || "issue"),
      severity: normalize_severity(Map.get(issue, :severity) || Map.get(issue, "severity")),
      source: normalize_source(Map.get(issue, :source) || Map.get(issue, "source"))
    }
  end

  defp normalize_code(value) when is_atom(value), do: value

  defp normalize_code(value) when is_binary(value) do
    case safe_to_existing_atom(value) do
      {:ok, atom} -> atom
      :error -> String.to_atom(value)
    end
  end

  defp normalize_code(_other), do: nil

  defp normalize_line(value) when is_integer(value) and value > 0, do: value
  defp normalize_line(_other), do: nil

  defp normalize_severity(:error), do: :error
  defp normalize_severity("error"), do: :error
  defp normalize_severity(_other), do: :warning

  defp normalize_source(source) when source in [:quality, :security, :syntax], do: source
  defp normalize_source("quality"), do: :quality
  defp normalize_source("security"), do: :security
  defp normalize_source("syntax"), do: :syntax
  defp normalize_source(source) when is_atom(source), do: source
  defp normalize_source(_other), do: :quality

  defp safe_to_existing_atom(value) do
    {:ok, String.to_existing_atom(value)}
  rescue
    ArgumentError -> :error
  end

  defp query_tags(issue) do
    base =
      case issue.source do
        :security -> [:security]
        :quality -> [:quality]
        _other -> []
      end

    code_tags =
      case issue.code do
        nil -> []
        atom when is_atom(atom) -> [atom]
        _other -> []
      end

    cwe_tags =
      case issue.code do
        :system_cmd -> [:cwe_78]
        :code_eval_string -> [:cwe_95]
        _other -> []
      end

    Enum.uniq(base ++ code_tags ++ cwe_tags)
  end

  defp issue_type(issue) do
    cond do
      issue.source == :security -> :security
      issue.source == :quality -> :quality
      issue.source == :syntax -> :syntax
      true -> :general
    end
  end

  defp ontology_context(issue) do
    case issue.source do
      :security ->
        %{
          class: "security.vulnerability",
          cwe: cwe_for_code(issue.code),
          namespace: "sobelow"
        }

      :quality ->
        %{
          class: "quality.style",
          namespace: "credo",
          rule: issue.code
        }

      :syntax ->
        %{
          class: "compiler.syntax",
          namespace: "elixir"
        }

      _other ->
        %{
          class: "general.issue",
          namespace: "elixir"
        }
    end
  end

  defp cwe_for_code(:system_cmd), do: "CWE-78"
  defp cwe_for_code(:code_eval_string), do: "CWE-95"
  defp cwe_for_code(_other), do: nil

  defp explanation_templates(issue, context, docs) do
    what = what_text(issue, context)
    why = why_text(issue, docs)
    how_to_fix = fix_steps(issue)
    fix_example = example_fix(issue)

    {what, why, how_to_fix, fix_example}
  end

  defp what_text(issue, context) do
    line_text =
      case issue.line do
        nil -> "within the shown snippet"
        line -> "around line #{line}"
      end

    """
    Detected `#{issue.code || :issue}` (#{issue.source}) #{line_text}. Message: #{issue.message}
    Snippet range: #{elem(context.line_range, 0)}-#{elem(context.line_range, 1)}.
    """
    |> String.trim()
  end

  defp why_text(issue, docs) do
    doc_hint =
      case docs do
        [%{title: title} | _rest] -> "Related guidance: #{title}."
        _ -> "Follow project quality/security policy for this issue type."
      end

    case issue.source do
      :security ->
        "Security issues can expose vulnerabilities or unsafe runtime behavior. #{doc_hint}"

      :quality ->
        "Quality issues reduce maintainability and may hide defects over time. #{doc_hint}"

      :syntax ->
        "Syntax issues prevent compilation and block execution. #{doc_hint}"

      _ ->
        "This issue should be addressed before returning generated code. #{doc_hint}"
    end
  end

  defp fix_steps(issue) do
    base_steps =
      case issue.code do
        :io_inspect ->
          [
            "Remove IO.inspect/1 calls from non-debug paths.",
            "Use structured logging only where operationally required."
          ]

        :system_cmd ->
          [
            "Validate and constrain command inputs before execution.",
            "Prefer allow-listed commands and arguments."
          ]

        :code_eval_string ->
          [
            "Avoid dynamic evaluation of untrusted data.",
            "Replace eval with explicit parsing and pattern matching."
          ]

        _other ->
          [
            "Rewrite the affected block with explicit safe control flow.",
            "Add tests covering the failure mode and expected fix."
          ]
      end

    if issue.source == :security do
      base_steps ++ ["Document threat assumptions and verify with security checks."]
    else
      base_steps
    end
  end

  defp example_fix(issue) do
    case issue.code do
      :io_inspect ->
        """
        def process(input) do
          # do work without debug prints in production path
          {:ok, transform(input)}
        end
        """

      :system_cmd ->
        """
        def run_safe(command) when command in ["git", "mix"] do
          System.cmd(command, [], stderr_to_stdout: true)
        end
        """

      :code_eval_string ->
        """
        def parse_integer(text) do
          case Integer.parse(text) do
            {value, ""} -> {:ok, value}
            _ -> {:error, :invalid_integer}
          end
        end
        """

      _other ->
        """
        def safe_handle(input) do
          with {:ok, value} <- validate(input) do
            {:ok, value}
          else
            {:error, reason} -> {:error, reason}
          end
        end
        """
    end
    |> String.trim()
  end
end
