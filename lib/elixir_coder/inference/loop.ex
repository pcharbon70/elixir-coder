defmodule ElixirCoder.Inference.Loop do
  @moduledoc """
  Generate-check-repair orchestration for inference candidates.

  The loop behavior is backend-agnostic:
  - generation can be backed by Edifice or fallback runtime adapters
  - candidate checks run through syntax/quality/security/policy stages
  - repair retries are bounded (default max attempts: 3)
  """

  alias ElixirCoder.Inference.Backend
  alias ElixirCoder.Inference.Check
  alias ElixirCoder.Inference.Generation
  alias ElixirCoder.Inference.Repair

  @type issue :: %{
          code: atom() | nil,
          line: non_neg_integer() | nil,
          message: String.t(),
          severity: :warning | :error,
          source: atom()
        }

  @type result :: %{
          attempt: pos_integer(),
          backend: atom() | nil,
          candidate_rank: pos_integer(),
          checks: map(),
          code: String.t(),
          repair_history: [map()],
          request_metadata: map() | nil,
          warnings: [map()]
        }

  @spec generate_with_repair(String.t(), map() | keyword(), keyword()) ::
          {:ok, result()} | {:error, term()}
  def generate_with_repair(prompt, clarification_answers, opts \\ [])
      when is_binary(prompt) and is_list(opts) do
    max_attempts = Keyword.get(opts, :max_attempts, 3)

    with :ok <- validate_max_attempts(max_attempts) do
      do_generate_with_repair(
        prompt,
        prompt,
        clarification_answers,
        opts,
        1,
        max_attempts,
        nil,
        []
      )
    end
  end

  defp do_generate_with_repair(
         original_prompt,
         active_prompt,
         clarification_answers,
         opts,
         attempt,
         max_attempts,
         forced_candidates,
         history
       ) do
    with {:ok, candidates} <-
           resolve_candidates(
             active_prompt,
             clarification_answers,
             opts,
             attempt,
             forced_candidates
           ),
         {:ok, evaluated_candidates} <-
           evaluate_candidates(original_prompt, candidates, opts) do
      case Enum.find(evaluated_candidates, & &1.clean?) do
        %{candidate: candidate} = clean_candidate ->
          {:ok,
           %{
             attempt: attempt,
             backend: clean_candidate.backend,
             candidate_rank: clean_candidate.rank,
             checks: clean_candidate.checks,
             code: candidate.code,
             repair_history: Enum.reverse(history),
             request_metadata: clean_candidate.request_metadata,
             warnings: clean_candidate.warnings
           }}

        nil ->
          best_candidate = pick_best_candidate(evaluated_candidates)

          if attempt >= max_attempts do
            {:error,
             {:no_clean_candidate,
              %{
                attempts: attempt,
                issues: best_candidate.issues,
                last_code: best_candidate.candidate.code,
                repair_history: Enum.reverse(history)
              }}}
          else
            repair_prompt =
              Repair.build_prompt(
                original_prompt,
                best_candidate.candidate.code,
                best_candidate.issues,
                policy_report: best_candidate.policy_report
              )

            case repair_candidate(repair_prompt, best_candidate, opts, attempt) do
              {:ok, repaired_code} ->
                repaired_candidate = %{
                  code: repaired_code,
                  metadata: %{
                    repaired_from_attempt: attempt
                  },
                  score: best_candidate.candidate.score
                }

                next_history =
                  [
                    %{
                      attempt: attempt,
                      issues: best_candidate.issues,
                      repair_prompt: repair_prompt
                    }
                    | history
                  ]

                do_generate_with_repair(
                  original_prompt,
                  repair_prompt,
                  clarification_answers,
                  opts,
                  attempt + 1,
                  max_attempts,
                  [repaired_candidate],
                  next_history
                )

              {:error, reason} ->
                {:error, {:repair_failed, attempt, reason}}
            end
          end
      end
    end
  end

  defp resolve_candidates(
         prompt,
         clarification_answers,
         opts,
         attempt,
         forced_candidates
       ) do
    case forced_candidates do
      nil ->
        generation_opts = generation_opts(opts, attempt, false)
        Generation.generate(prompt, clarification_answers, generation_opts)

      candidates when is_list(candidates) ->
        {:ok, candidates}
    end
  end

  defp evaluate_candidates(prompt, candidates, opts) do
    candidates
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {candidate, rank}, {:ok, acc} ->
      case evaluate_candidate(prompt, candidate, rank, opts) do
        {:ok, evaluated} -> {:cont, {:ok, [evaluated | acc]}}
        {:fatal, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, evaluated} -> {:ok, Enum.reverse(evaluated)}
      {:error, _reason} = error -> error
    end
  end

  defp evaluate_candidate(prompt, candidate, rank, opts) do
    code = candidate.code

    syntax_result = Check.check_syntax(code)
    quality_result = Check.check_quality(code, quality_opts(opts))
    security_result = Check.check_security(code, security_opts(opts))

    policy_result =
      if match?({:ok, _ast}, syntax_result) do
        Backend.evaluate_candidate(prompt, code, generation_state(opts), backend_opts(opts))
      else
        {:skipped, :syntax_invalid}
      end

    case policy_result do
      {:error, {:backend_mismatch, _details} = reason} ->
        {:fatal, reason}

      {:error, {:unsupported_features, _details} = reason} ->
        {:fatal, reason}

      {:error, {:unsupported_enforce_mode, _details} = reason} ->
        {:fatal, reason}

      {:error, {:invalid_policy_mode, _mode} = reason} ->
        {:fatal, reason}

      {:error, {:invalid_mode, _mode} = reason} ->
        {:fatal, reason}

      _other ->
        issues =
          []
          |> collect_syntax_issue(syntax_result)
          |> collect_check_issues(quality_result)
          |> collect_check_issues(security_result)
          |> collect_policy_issues(policy_result)

        {backend, request_metadata, warnings, policy_report} =
          extract_policy_metadata(policy_result)

        clean? =
          match?({:ok, _}, syntax_result) and
            match?({:ok, _}, quality_result) and
            match?({:ok, _}, security_result) and
            match?({:ok, _}, policy_result)

        {:ok,
         %{
           backend: backend,
           candidate: candidate,
           checks: %{
             policy: summarize_policy_check(policy_result),
             quality: summarize_check(quality_result),
             security: summarize_check(security_result),
             syntax: summarize_check(syntax_result)
           },
           clean?: clean?,
           issues: issues,
           policy_report: policy_report,
           rank: rank,
           request_metadata: request_metadata,
           warnings: warnings
         }}
    end
  end

  defp collect_syntax_issue(issues, {:ok, _ast}), do: issues

  defp collect_syntax_issue(issues, {:error, syntax_error}) do
    [
      %{
        code: nil,
        line: syntax_error.line,
        message: syntax_error.description,
        severity: :error,
        source: :syntax
      }
      | issues
    ]
  end

  defp collect_check_issues(issues, {:ok, _}), do: issues

  defp collect_check_issues(issues, {:error, check_issues}) when is_list(check_issues),
    do: check_issues ++ issues

  defp collect_policy_issues(issues, {:ok, _policy_result}), do: issues

  defp collect_policy_issues(issues, {:error, {:policy_violations, report}}) do
    policy_issues =
      Enum.map(report.violations, fn violation ->
        %{
          code: violation.non_compliance_reason,
          line: violation.line,
          message: violation.message,
          severity: :error,
          source: :policy
        }
      end)

    policy_issues ++ issues
  end

  defp collect_policy_issues(issues, {:skipped, _reason}), do: issues
  defp collect_policy_issues(issues, {:error, _other}), do: issues

  defp extract_policy_metadata({:ok, policy_result}) do
    {
      policy_result.backend,
      policy_result.request_metadata,
      policy_result.warnings,
      policy_result.policy_report
    }
  end

  defp extract_policy_metadata({:error, {:policy_violations, report}}) do
    {nil, nil, [], report}
  end

  defp extract_policy_metadata(_other), do: {nil, nil, [], nil}

  defp summarize_check({:ok, _value}), do: :ok

  defp summarize_check({:error, issues}) when is_list(issues) do
    {:error, length(issues)}
  end

  defp summarize_check({:error, _reason}), do: {:error, 1}

  defp summarize_policy_check({:ok, result}) do
    if result.policy_report.compliant? do
      :ok
    else
      {:warn, length(result.warnings)}
    end
  end

  defp summarize_policy_check({:error, {:policy_violations, report}}),
    do: {:error, length(report.violations)}

  defp summarize_policy_check({:error, _reason}), do: {:error, 1}
  defp summarize_policy_check({:skipped, _reason}), do: :skipped

  defp pick_best_candidate(evaluated_candidates) do
    Enum.min_by(evaluated_candidates, fn candidate ->
      {length(candidate.issues), -candidate.candidate.score, candidate.rank}
    end)
  end

  defp repair_candidate(repair_prompt, best_candidate, opts, attempt) do
    case Keyword.get(opts, :repair_generator) do
      repair_generator when is_function(repair_generator, 3) ->
        case repair_generator.(repair_prompt, best_candidate.candidate.code, %{
               attempt: attempt,
               issues: best_candidate.issues
             }) do
          {:ok, repaired_code} when is_binary(repaired_code) ->
            {:ok, repaired_code}

          {:error, _reason} = error ->
            error

          repaired_code when is_binary(repaired_code) ->
            {:ok, repaired_code}

          other ->
            {:error, {:invalid_repair_generator_output, other}}
        end

      nil ->
        fallback_repair_candidate(repair_prompt, opts, attempt)

      other ->
        {:error, {:invalid_repair_generator, other}}
    end
  end

  defp fallback_repair_candidate(repair_prompt, opts, attempt) do
    repair_generation_opts = generation_opts(opts, attempt + 1, true)

    with {:ok, candidates} <- Generation.generate(repair_prompt, %{}, repair_generation_opts),
         [%{code: code} | _rest] <- candidates do
      {:ok, code}
    else
      {:error, _reason} = error -> error
      _other -> {:error, :repair_generation_failed}
    end
  end

  defp validate_max_attempts(value) when is_integer(value) and value > 0, do: :ok
  defp validate_max_attempts(value), do: {:error, {:invalid_max_attempts, value}}

  defp generation_opts(opts, attempt, repair?) do
    opts
    |> Keyword.get(:generation_opts, [])
    |> Keyword.put(:attempt, attempt)
    |> Keyword.put(:repair?, repair?)
  end

  defp generation_state(opts) do
    Keyword.get(opts, :generation_state, %{})
  end

  defp quality_opts(opts) do
    case Keyword.get(opts, :quality_checker) do
      checker when is_function(checker, 1) -> [quality_checker: checker]
      _other -> []
    end
  end

  defp security_opts(opts) do
    case Keyword.get(opts, :security_checker) do
      checker when is_function(checker, 1) -> [security_checker: checker]
      _other -> []
    end
  end

  defp backend_opts(opts) do
    Keyword.take(opts, [
      :allow_fallback?,
      :backend,
      :backend_mismatch_mode,
      :context,
      :fallback_backend,
      :required_features,
      :policy_context,
      :policy_mode
    ])
  end
end
