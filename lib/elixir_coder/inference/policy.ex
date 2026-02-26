defmodule ElixirCoder.Inference.Policy do
  @moduledoc """
  OTP supervision policy checks for inference-time code generation.

  Policy axis:
  - `:supervised_internal`: avoid blanket `try/rescue/catch`; let OTP supervision restart crashes
  - `:boundary_handling`: explicitly handle expected external/input errors
  - `:mixed`: apply both perspectives
  """

  @type context :: :supervised_internal | :boundary_handling | :mixed

  @type non_compliance_reason ::
          :broad_rescue_internal
          | :missing_boundary_validation
          | :swallowed_exception
          | :unsafe_raise_boundary

  @type violation :: %{
          line: non_neg_integer() | nil,
          message: String.t(),
          non_compliance_reason: non_compliance_reason()
        }

  @type report :: %{
          code: String.t() | nil,
          compliant?: boolean(),
          context: context(),
          violations: [violation()]
        }

  @context_keywords %{
    supervised_internal: [
      "genserver",
      "supervisor",
      "otp",
      "handle_call",
      "handle_cast",
      "handle_info",
      "child_spec",
      "start_link",
      "process"
    ],
    boundary_handling: [
      "controller",
      "plug",
      "endpoint",
      "http",
      "api",
      "request",
      "params",
      "cli",
      "task",
      "input",
      "external"
    ]
  }

  @spec classify_context(String.t(), keyword()) :: %{
          boundary_score: non_neg_integer(),
          context: context(),
          internal_score: non_neg_integer(),
          source: :heuristic | :override
        }
  def classify_context(prompt, opts \\ []) when is_binary(prompt) and is_list(opts) do
    case parse_context(Keyword.get(opts, :context)) do
      {:ok, context} ->
        %{
          boundary_score: 0,
          context: context,
          internal_score: 0,
          source: :override
        }

      :error ->
        text = String.downcase(prompt)
        internal_score = keyword_hits(text, @context_keywords.supervised_internal)
        boundary_score = keyword_hits(text, @context_keywords.boundary_handling)

        %{
          boundary_score: boundary_score,
          context: choose_context(internal_score, boundary_score),
          internal_score: internal_score,
          source: :heuristic
        }
    end
  end

  @spec check_ast(String.t() | Macro.t(), keyword()) :: {:ok, report()} | {:error, term()}
  def check_ast(code_or_ast, opts \\ [])

  def check_ast(code, opts) when is_binary(code) and is_list(opts) do
    with {:ok, ast} <- Code.string_to_quoted(code),
         {:ok, report} <- check_ast(ast, Keyword.put(opts, :code, code)) do
      {:ok, report}
    else
      {:error, _reason} = error -> error
    end
  end

  def check_ast(ast, opts) when is_list(opts) do
    with {:ok, context} <- parse_context(Keyword.get(opts, :context, :mixed)) do
      analysis = analyze_ast(ast)
      violations = build_violations(context, analysis)

      {:ok,
       %{
         code: Keyword.get(opts, :code),
         compliant?: violations == [],
         context: context,
         violations: violations
       }}
    end
  end

  @spec build_repair_prompt(String.t(), String.t(), report()) :: String.t()
  def build_repair_prompt(original_prompt, code, report)
      when is_binary(original_prompt) and is_binary(code) and is_map(report) do
    violation_lines =
      report.violations
      |> Enum.map_join("\n", fn violation ->
        "- `#{violation.non_compliance_reason}`#{line_suffix(violation.line)}: #{violation.message}"
      end)

    context_guidance = context_guidance(report.context)

    """
    You are repairing Elixir code to satisfy OTP supervision policy.

    Context: `#{report.context}`
    Guidance: #{context_guidance}

    Violations:
    #{violation_lines}

    Original request:
    #{original_prompt}

    Current code:
    ```elixir
    #{code}
    ```

    Rewrite the code to remove the listed violations while preserving intended behavior.
    """
  end

  @spec evaluate_output(String.t(), String.t(), keyword()) ::
          {:ok,
           %{
             code: String.t(),
             context: context(),
             policy_mode: :warn | :enforce,
             policy_report: report(),
             warnings: [violation()]
           }}
          | {:error, {:policy_violations, report()}}
          | {:error, term()}
  def evaluate_output(prompt, code, opts \\ [])
      when is_binary(prompt) and is_binary(code) and is_list(opts) do
    policy_mode = Keyword.get(opts, :policy_mode, :warn)
    context = Keyword.get(opts, :context) || classify_context(prompt, opts).context

    with {:ok, report} <- check_ast(code, context: context) do
      case {policy_mode, report.compliant?} do
        {:warn, _} ->
          {:ok,
           %{
             code: code,
             context: report.context,
             policy_mode: :warn,
             policy_report: report,
             warnings: report.violations
           }}

        {:enforce, true} ->
          {:ok,
           %{
             code: code,
             context: report.context,
             policy_mode: :enforce,
             policy_report: report,
             warnings: []
           }}

        {:enforce, false} ->
          {:error, {:policy_violations, report}}

        {mode, _} ->
          {:error, {:invalid_policy_mode, mode}}
      end
    end
  end

  defp analyze_ast(ast) do
    initial = %{
      bang_calls: [],
      has_case_error_handling?: false,
      has_with_error_handling?: false,
      raise_calls: [],
      try_blocks: []
    }

    {_ast, state} =
      Macro.prewalk(ast, initial, fn node, acc ->
        {node, analyze_node(node, acc)}
      end)

    state
  end

  defp analyze_node({:with, _meta, args}, acc) do
    with_error? = with_handles_error?(args)
    %{acc | has_with_error_handling?: acc.has_with_error_handling? or with_error?}
  end

  defp analyze_node({:case, _meta, [_subject, clauses]}, acc) when is_list(clauses) do
    case_error? = case_handles_error?(clauses)
    %{acc | has_case_error_handling?: acc.has_case_error_handling? or case_error?}
  end

  defp analyze_node({:try, meta, [clauses]} = _node, acc) when is_list(clauses) do
    rescue_clauses =
      clauses
      |> Keyword.get(:rescue, [])
      |> normalize_clauses()

    catch_clauses =
      clauses
      |> Keyword.get(:catch, [])
      |> normalize_clauses()

    broad_rescue? =
      catch_clauses != [] or Enum.any?(rescue_clauses, &broad_rescue_clause?/1)

    swallowed? =
      broad_rescue? and
        Enum.any?(rescue_clauses, fn clause ->
          broad_rescue_clause?(clause) and rescue_clause_swallows?(clause)
        end)

    try_block = %{
      broad_rescue?: broad_rescue?,
      line: line(meta),
      swallowed?: swallowed?
    }

    %{acc | try_blocks: [try_block | acc.try_blocks]}
  end

  defp analyze_node(node, acc) do
    case call_info(node) do
      {:ok, function_name, line_no} ->
        acc
        |> maybe_record_bang_call(function_name, line_no)
        |> maybe_record_raise_call(function_name, line_no)

      :error ->
        acc
    end
  end

  defp maybe_record_bang_call(acc, function_name, line_no) do
    if String.ends_with?(Atom.to_string(function_name), "!") do
      %{acc | bang_calls: [%{function: function_name, line: line_no} | acc.bang_calls]}
    else
      acc
    end
  end

  defp maybe_record_raise_call(acc, function_name, line_no) do
    if function_name in [:raise, :reraise] do
      %{acc | raise_calls: [%{function: function_name, line: line_no} | acc.raise_calls]}
    else
      acc
    end
  end

  defp call_info({function_name, meta, args}) when is_atom(function_name) and is_list(args) do
    {:ok, function_name, line(meta)}
  end

  defp call_info({{:., _dot_meta, [_module, function_name]}, meta, args})
       when is_atom(function_name) and is_list(args) do
    {:ok, function_name, line(meta)}
  end

  defp call_info(_node), do: :error

  defp build_violations(context, analysis) do
    []
    |> maybe_add_internal_broad_rescue(context, analysis)
    |> maybe_add_swallowed_exception(context, analysis)
    |> maybe_add_missing_boundary_validation(context, analysis)
    |> maybe_add_unsafe_raise_boundary(context, analysis)
    |> Enum.reverse()
  end

  defp maybe_add_internal_broad_rescue(violations, context, analysis) do
    if context in [:supervised_internal, :mixed] do
      Enum.reduce(analysis.try_blocks, violations, fn block, acc ->
        if block.broad_rescue? do
          [
            %{
              line: block.line,
              message:
                "Avoid blanket try/rescue/catch in supervised internals; let OTP supervision restart failures.",
              non_compliance_reason: :broad_rescue_internal
            }
            | acc
          ]
        else
          acc
        end
      end)
    else
      violations
    end
  end

  defp maybe_add_swallowed_exception(violations, context, analysis) do
    if context in [:supervised_internal, :mixed] do
      Enum.reduce(analysis.try_blocks, violations, fn block, acc ->
        if block.swallowed? do
          [
            %{
              line: block.line,
              message:
                "Do not swallow rescued exceptions silently; convert expected errors explicitly or re-raise unexpected ones.",
              non_compliance_reason: :swallowed_exception
            }
            | acc
          ]
        else
          acc
        end
      end)
    else
      violations
    end
  end

  defp maybe_add_missing_boundary_validation(violations, context, analysis) do
    boundary_missing? =
      context in [:boundary_handling, :mixed] and
        analysis.bang_calls != [] and
        not (analysis.has_case_error_handling? or analysis.has_with_error_handling?)

    if boundary_missing? do
      first_line =
        analysis.bang_calls
        |> Enum.map(& &1.line)
        |> Enum.filter(&is_integer/1)
        |> Enum.min(fn -> nil end)

      [
        %{
          line: first_line,
          message:
            "Boundary code should handle expected external/input failures explicitly instead of relying on bang calls without validation.",
          non_compliance_reason: :missing_boundary_validation
        }
        | violations
      ]
    else
      violations
    end
  end

  defp maybe_add_unsafe_raise_boundary(violations, context, analysis) do
    if context in [:boundary_handling, :mixed] and analysis.raise_calls != [] do
      first_line =
        analysis.raise_calls
        |> Enum.map(& &1.line)
        |> Enum.filter(&is_integer/1)
        |> Enum.min(fn -> nil end)

      [
        %{
          line: first_line,
          message:
            "Boundary handling should avoid raw raise for expected failures; return explicit error tuples or validated responses.",
          non_compliance_reason: :unsafe_raise_boundary
        }
        | violations
      ]
    else
      violations
    end
  end

  defp with_handles_error?(parts) when is_list(parts) do
    has_error_match? =
      Enum.any?(parts, fn
        {:<-, _meta, [pattern, _value]} -> error_pattern?(pattern)
        _other -> false
      end)

    else_error_match? =
      parts
      |> Enum.find_value([], fn
        {:else, clauses} -> clauses
        _other -> nil
      end)
      |> normalize_clauses()
      |> Enum.any?(fn
        {:->, _meta, [patterns, _body]} ->
          patterns
          |> normalize_patterns()
          |> Enum.any?(&error_pattern?/1)

        _other ->
          false
      end)

    has_error_match? or else_error_match?
  end

  defp case_handles_error?(clauses) when is_list(clauses) do
    do_clauses =
      clauses
      |> Keyword.get(:do, [])
      |> normalize_clauses()

    Enum.any?(do_clauses, fn
      {:->, _meta, [patterns, _body]} ->
        patterns
        |> normalize_patterns()
        |> Enum.any?(&error_pattern?/1)

      _other ->
        false
    end)
  end

  defp broad_rescue_clause?({:->, _meta, [patterns, _body]}) do
    patterns
    |> normalize_patterns()
    |> Enum.any?(&broad_rescue_pattern?/1)
  end

  defp broad_rescue_clause?(_other), do: true

  defp rescue_clause_swallows?({:->, _meta, [_patterns, body]}) do
    not contains_reraise_or_raise?(body) and simple_return?(body)
  end

  defp rescue_clause_swallows?(_other), do: false

  defp contains_reraise_or_raise?(ast) do
    {_ast, contains?} =
      Macro.prewalk(ast, false, fn node, acc ->
        case call_info(node) do
          {:ok, function_name, _line} when function_name in [:raise, :reraise, :exit, :throw] ->
            {node, true}

          _other ->
            {node, acc}
        end
      end)

    contains?
  end

  defp simple_return?(expr) do
    expr = last_expr(expr)

    cond do
      is_atom(expr) -> true
      is_binary(expr) -> true
      is_number(expr) -> true
      is_list(expr) -> true
      match?({:%{}, _, _}, expr) -> true
      match?({:{}, _, _}, expr) -> true
      true -> false
    end
  end

  defp last_expr({:__block__, _meta, expressions}) when is_list(expressions),
    do: List.last(expressions)

  defp last_expr(expr), do: expr

  defp broad_rescue_pattern?({:_, _meta, _context}), do: true

  defp broad_rescue_pattern?({:when, _meta, [pattern, _guard]}),
    do: broad_rescue_pattern?(pattern)

  defp broad_rescue_pattern?({:in, _meta, [_var, _exceptions]}), do: false

  defp broad_rescue_pattern?({name, _meta, context})
       when is_atom(name) and (is_atom(context) or is_nil(context)),
       do: true

  defp broad_rescue_pattern?({:__aliases__, _meta, _parts}), do: false
  defp broad_rescue_pattern?({:%, _meta, [_exception, _map]}), do: false
  defp broad_rescue_pattern?(_other), do: true

  defp error_pattern?(pattern) do
    {_pattern, found?} =
      Macro.prewalk(pattern, false, fn
        :error, _acc -> {:error, true}
        {:error, _value} = node, _acc -> {node, true}
        node, acc -> {node, acc}
      end)

    found?
  end

  defp normalize_patterns(patterns) when is_list(patterns), do: patterns
  defp normalize_patterns(patterns), do: [patterns]

  defp normalize_clauses(nil), do: []
  defp normalize_clauses(clauses) when is_list(clauses), do: clauses
  defp normalize_clauses(clause), do: [clause]

  defp parse_context(value) when value in [:supervised_internal, :boundary_handling, :mixed],
    do: {:ok, value}

  defp parse_context(value) when is_binary(value) do
    case value do
      "supervised_internal" -> {:ok, :supervised_internal}
      "boundary_handling" -> {:ok, :boundary_handling}
      "mixed" -> {:ok, :mixed}
      _other -> :error
    end
  end

  defp parse_context(nil), do: :error
  defp parse_context(_other), do: :error

  defp choose_context(internal_score, boundary_score) do
    cond do
      internal_score > 0 and boundary_score == 0 -> :supervised_internal
      boundary_score > 0 and internal_score == 0 -> :boundary_handling
      true -> :mixed
    end
  end

  defp keyword_hits(text, keywords) do
    Enum.count(keywords, &String.contains?(text, &1))
  end

  defp line(meta) when is_list(meta), do: Keyword.get(meta, :line)
  defp line(_meta), do: nil

  defp line_suffix(nil), do: ""
  defp line_suffix(line), do: " at line #{line}"

  defp context_guidance(:supervised_internal) do
    "Supervised internals should crash on invariant violations and avoid blanket rescue/catch."
  end

  defp context_guidance(:boundary_handling) do
    "Boundary handling must validate external input and return explicit expected-error outcomes."
  end

  defp context_guidance(:mixed) do
    "Apply OTP crash-friendly behavior for internals and explicit expected-error handling at boundaries."
  end
end
