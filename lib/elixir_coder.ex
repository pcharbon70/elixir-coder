defmodule ElixirCoder do
  @moduledoc """
  Public inference API for Elixir code generation workflows.
  """

  alias ElixirCoder.Inference.Explanation
  alias ElixirCoder.Inference.Loop
  alias ElixirCoder.Inference.Policy

  @default_policy_mode :warn
  @default_max_attempts 3

  @spec generate(String.t(), keyword()) ::
          {:ok, String.t() | map()} | {:clarification_needed, map()} | {:error, term()}
  def generate(prompt, opts \\ []) when is_binary(prompt) and is_list(opts) do
    if should_ask_clarification?(prompt, opts) and not Keyword.get(opts, :force_generate?, false) do
      {:clarification_needed, clarification_question(prompt, opts)}
    else
      run_generation(prompt, %{}, opts)
    end
  end

  @spec generate_with_clarification(String.t(), map() | keyword(), keyword()) ::
          {:ok, String.t() | map()} | {:error, term()}
  def generate_with_clarification(prompt, clarification_answers, opts \\ [])
      when is_binary(prompt) and is_list(opts) do
    normalized_answers = normalize_answers(clarification_answers)

    run_generation(
      prompt,
      normalized_answers,
      Keyword.put(opts, :force_generate?, true)
    )
  end

  @spec ask_clarification(String.t(), keyword()) :: {:ok, map()}
  def ask_clarification(prompt, opts \\ []) when is_binary(prompt) and is_list(opts) do
    {:ok, clarification_question(prompt, opts)}
  end

  @spec answer_clarification(String.t(), String.t() | map(), String.t() | map()) ::
          {:ok, String.t() | map()} | {:error, term()}
  def answer_clarification(prompt, question, answer)
      when is_binary(prompt) and (is_binary(question) or is_map(question)) do
    clarification =
      case question do
        question_text when is_binary(question_text) ->
          %{
            answer: answer,
            question: question_text
          }

        question_map when is_map(question_map) ->
          question_map
          |> Map.put(:answer, answer)
      end

    generate_with_clarification(prompt, clarification, [])
  end

  @spec explain(String.t(), map()) :: {:ok, String.t()} | {:error, term()}
  def explain(code, issue) when is_binary(code) and is_map(issue) do
    with {:ok, explanation} <- Explanation.explain(code, issue) do
      {:ok, explanation.markdown}
    end
  end

  @spec generate_batch([String.t()], keyword()) :: [
          {:ok, String.t() | map()} | {:clarification_needed, map()} | {:error, term()}
        ]
  def generate_batch(prompts, opts \\ []) when is_list(prompts) and is_list(opts) do
    max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())
    timeout = Keyword.get(opts, :timeout, 30_000)

    prompts
    |> Task.async_stream(
      fn prompt ->
        generate(prompt, opts)
      end,
      max_concurrency: max_concurrency,
      ordered: true,
      timeout: timeout
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, reason} -> {:error, {:batch_task_exit, reason}}
    end)
  end

  defp run_generation(prompt, clarification_answers, opts) do
    context =
      Keyword.get(opts, :context) ||
        inferred_context(prompt, clarification_answers, opts)

    loop_opts =
      opts
      |> Keyword.put_new(:policy_mode, @default_policy_mode)
      |> Keyword.put_new(:max_attempts, @default_max_attempts)
      |> Keyword.put_new(:context, context)
      |> Keyword.put_new_lazy(:generation_opts, fn ->
        default_generation_opts(prompt, clarification_answers)
      end)

    with {:ok, result} <- Loop.generate_with_repair(prompt, clarification_answers, loop_opts) do
      if Keyword.get(opts, :include_metadata?, false) do
        {:ok,
         %{
           code: result.code,
           context: context,
           request_metadata: result.request_metadata,
           warnings: result.warnings
         }}
      else
        {:ok, result.code}
      end
    end
  end

  defp should_ask_clarification?(prompt, opts) do
    min_words = Keyword.get(opts, :clarification_min_words, 4)
    prompt_words = prompt |> String.split() |> length()

    ambiguous_tokens = [
      "something",
      "stuff",
      "whatever",
      "somehow",
      "thing",
      "things",
      "etc",
      "it"
    ]

    has_ambiguous_tokens? =
      prompt
      |> String.downcase()
      |> then(fn text ->
        Enum.any?(ambiguous_tokens, &String.contains?(text, &1))
      end)

    prompt_words < min_words or has_ambiguous_tokens?
  end

  defp clarification_question(prompt, opts) do
    type = Keyword.get(opts, :clarification_type, :requirements)

    %{
      id: :clarify_requirements,
      prompt: prompt,
      question:
        "Can you clarify expected inputs, failure behavior, and desired output shape for this request?",
      type: type
    }
  end

  defp inferred_context(prompt, clarification_answers, opts) do
    context_text =
      [
        prompt,
        Map.get(normalize_answers(clarification_answers), :answer),
        Keyword.get(opts, :context_hint)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    Policy.classify_context(context_text, opts).context
  end

  defp default_generation_opts(_prompt, _clarification_answers) do
    [
      candidates: [
        %{
          code: """
          defmodule Generated do
            def run(input) do
              {:ok, input}
            end
          end
          """,
          score: 0.1
        }
      ]
    ]
  end

  defp normalize_answers(answers) when is_map(answers), do: answers
  defp normalize_answers(answers) when is_list(answers), do: Enum.into(answers, %{})
  defp normalize_answers(answer) when is_binary(answer), do: %{answer: answer}
  defp normalize_answers(_other), do: %{}
end
