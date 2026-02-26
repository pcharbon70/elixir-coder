defmodule ElixirCoder.Inference.ExplanationTest do
  use ExUnit.Case, async: true

  alias ElixirCoder.Inference.Explanation

  test "extract_context returns snippet, issue details, and ontology context" do
    code = """
    defmodule Demo do
      def run(cmd) do
        System.cmd(cmd, [])
      end
    end
    """

    issue = %{
      code: :system_cmd,
      line: 3,
      message: "System.cmd is unsafe",
      severity: :error,
      source: :security
    }

    context = Explanation.extract_context(code, issue, snippet_radius: 1)

    assert context.issue.code == :system_cmd
    assert context.issue.source == :security
    assert context.code_snippet =~ "System.cmd(cmd, [])"
    assert context.line_range == {2, 4}
    assert context.ontology.namespace == "sobelow"
    assert context.ontology.cwe == "CWE-78"
  end

  test "retrieve_docs returns relevant snippets including cwe references" do
    issue = %{
      code: :system_cmd,
      message: "System.cmd is unsafe",
      severity: :error,
      source: :security
    }

    docs = Explanation.retrieve_docs(issue, max_docs: 5)

    assert docs != []
    assert Enum.any?(docs, &(&1.source == :sobelow))
    assert Enum.any?(docs, &(&1.source == :cwe))
  end

  test "generate produces explanation text and fix suggestions" do
    code = """
    defmodule Demo do
      def run(data), do: IO.inspect(data)
    end
    """

    issue = %{
      code: :io_inspect,
      line: 2,
      message: "Avoid IO.inspect",
      severity: :warning,
      source: :quality
    }

    context = Explanation.extract_context(code, issue)
    docs = Explanation.retrieve_docs(issue)
    explanation = Explanation.generate(context, docs)

    assert explanation.issue_type == :quality
    assert is_binary(explanation.what)
    assert is_binary(explanation.why)
    assert explanation.how_to_fix != []
    assert is_binary(explanation.fix_example)
  end

  test "format_markdown returns structured markdown output" do
    explanation = %{
      docs: [
        %{
          context: "Example doc",
          source: :credo,
          tags: [:quality],
          title: "Credo docs",
          url: "https://hexdocs.pm/credo/readme.html"
        }
      ],
      fix_example: "def ok, do: :ok",
      how_to_fix: ["Apply fix one", "Apply fix two"],
      issue_type: :quality,
      title: "Issue explanation",
      what: "What happened",
      why: "Why this matters"
    }

    markdown = Explanation.format_markdown(explanation)

    assert markdown =~ "# Issue explanation"
    assert markdown =~ "## What"
    assert markdown =~ "## Why It Matters"
    assert markdown =~ "## How To Fix"
    assert markdown =~ "## References"
    assert markdown =~ "```elixir"
  end

  test "explain runs full pipeline and returns markdown" do
    code = """
    defmodule Demo do
      def run(cmd), do: System.cmd(cmd, [])
    end
    """

    issue = %{
      code: :system_cmd,
      line: 2,
      message: "System.cmd is unsafe",
      severity: :error,
      source: :security
    }

    assert {:ok, result} = Explanation.explain(code, issue)

    assert is_map(result.context)
    assert is_list(result.docs)
    assert is_map(result.explanation)
    assert is_binary(result.markdown)
    assert result.markdown =~ "How To Fix"
  end
end
