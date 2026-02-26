defmodule ElixirCoder.ApiTest do
  use ExUnit.Case, async: true

  test "generate returns clarification_needed for ambiguous prompt" do
    assert {:clarification_needed, question} = ElixirCoder.generate("do something")
    assert question.id == :clarify_requirements
    assert is_binary(question.question)
  end

  test "generate returns code for concrete prompt" do
    opts = [
      force_generate?: true,
      generation_opts: [
        candidates: [
          %{
            code: "defmodule Demo do\n  def ok, do: :ok\nend",
            score: 0.9
          }
        ]
      ]
    ]

    assert {:ok, code} = ElixirCoder.generate("implement demo module", opts)
    assert code =~ "defmodule Demo"
  end

  test "generate_with_clarification returns code with forced clarification context" do
    opts = [
      generation_opts: [
        candidates: [
          %{
            code: "defmodule Clarified do\n  def run, do: {:ok, :done}\nend",
            score: 0.8
          }
        ]
      ]
    ]

    answers = %{answer: "Input is JSON, return {:ok, result} on success"}

    assert {:ok, code} = ElixirCoder.generate_with_clarification("build handler", answers, opts)
    assert code =~ "defmodule Clarified"
  end

  test "answer_clarification accepts question and answer and generates code" do
    question = "What should this function return on invalid input?"
    answer = "Return {:error, :invalid_input}"

    assert {:ok, code} =
             ElixirCoder.answer_clarification(
               "build function",
               question,
               answer
             )

    assert code =~ "defmodule Generated"
  end

  test "explain returns markdown explanation text" do
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

    assert {:ok, markdown} = ElixirCoder.explain(code, issue)
    assert markdown =~ "How To Fix"
    assert markdown =~ "References"
  end

  test "generate_batch returns ordered list of generation results" do
    prompts = ["implement alpha module", "implement beta module"]

    opts = [
      force_generate?: true,
      generation_opts: [
        candidates: [
          %{
            code: "defmodule Batch do\n  def ok, do: :ok\nend",
            score: 0.6
          }
        ]
      ]
    ]

    results = ElixirCoder.generate_batch(prompts, opts)

    assert length(results) == 2

    assert Enum.all?(results, fn
             {:ok, code} when is_binary(code) -> code =~ "defmodule Batch"
             _other -> false
           end)
  end

  test "generate returns error in enforce mode when candidate stays non-compliant" do
    opts = [
      force_generate?: true,
      context: :boundary_handling,
      max_attempts: 1,
      policy_mode: :enforce,
      generation_opts: [
        candidates: [
          %{
            code: """
            def create(params) do
              payload = Jason.decode!(params["payload"])
              raise "invalid"
              {:ok, payload}
            end
            """
          }
        ]
      ]
    ]

    assert {:error, {:no_clean_candidate, details}} =
             ElixirCoder.generate("implement API boundary handler", opts)

    assert details.issues != []
  end
end
