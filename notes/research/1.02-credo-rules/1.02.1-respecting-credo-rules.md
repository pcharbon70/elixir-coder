# Teaching code generation models to respect Credo's rules

**Bottom line:** Building a Credo-aware Elixir code generation model requires a multi-pronged approach combining training-time contrastive learning, inference-time constrained decoding, and retrieval-augmented explanation generation. The most practical path forward leverages Credo's AST-based rule definitions to generate contrastive training pairs, integrates lightweight syntax-focused checks during inference using monitor-guided decoding patterns, and produces explanations via chain-of-thought prompting grounded in retrieved Credo documentation.

This research provides implementation-ready strategies for your ontology-augmented Elixir code generation model, extending the existing RDF/OWL semantic framework to encompass Credo's static analysis rules. The architecture spans four integration points: **data pipeline** for training pair generation, **model architecture** for multi-task learning, **decoding loop** for constraint enforcement, and **explanation module** for natural language output.

---

## How Credo's rule architecture enables ML integration

Credo organizes **83+ checks** across five semantic categories, each targeting distinct code quality dimensions. Understanding this taxonomy is essential for designing effective training curricula and mapping rules to formal representations.

### The five-category rule taxonomy

| Category | Purpose | Exit Status | ML Amenability |
|----------|---------|-------------|----------------|
| **Consistency** | Cross-file uniformity (tabs vs. spaces, naming patterns) | 1 | Low—requires corpus-level analysis |
| **Design** | Architectural concerns (TODOs, alias usage, duplicated code) | 2 | Medium—context-dependent patterns |
| **Readability** | Convention adherence (module docs, naming, line length) | 4 | High—surface-level patterns |
| **Refactor** | Simplification opportunities (complexity, nesting, redundant ops) | 8 | High—structural patterns |
| **Warning** | Likely bugs (unused operations, leftover debug code) | 16 | High—semantic anti-patterns |

The **Readability** and **Warning** categories are most amenable to ML-based detection because they involve recognizable surface patterns: `IO.inspect` calls, snake_case violations, missing `@moduledoc` attributes. **Refactor** checks like cyclomatic complexity and nesting depth require structural analysis but remain tractable through AST encoding. **Consistency** checks pose the greatest challenge since they require comparing patterns across multiple files—a task better suited to traditional static analysis.

### Inside Credo's check module architecture

Every Credo check implements the `Credo.Check` behaviour, providing a standardized interface for rule definition:

```elixir
defmodule Credo.Check.Warning.IoInspect do
  use Credo.Check,
    id: "EX5025",
    category: :warning,
    base_priority: :high,
    explanations: [check: "IO.inspect should be removed before committing..."]

  @impl true
  def run(%SourceFile{} = source_file, params) do
    Credo.Code.prewalk(source_file, &traverse(&1, &2, IssueMeta.for(source_file, params)))
  end

  defp traverse({{:., _, [{:__aliases__, _, [:IO]}, :inspect]}, meta, _}, issues, meta) do
    {nil, issues ++ [format_issue(meta, message: "Found IO.inspect call", line_no: meta[:line])]}
  end
  defp traverse(ast, issues, _), do: {ast, issues}
end
```

This architecture reveals three key integration points: **AST pattern matching** for rule detection, **structured issue output** for training labels, and **configurable parameters** for rule customization. The `prewalk` and `postwalk` traversal functions enable systematic analysis of Elixir's three-tuple AST representation `{operation, metadata, arguments}`.

### Mapping Credo rules to RDF/OWL ontologies

Credo rules can extend your existing `elixir-core.ttl` ontology using SHACL (Shapes Constraint Language) for validation semantics:

```turtle
@prefix credo: <http://elixir-lang.org/credo#> .
@prefix sh: <http://www.w3.org/ns/shacl#> .

credo:IoInspectViolation a sh:NodeShape ;
    sh:targetClass elixir:FunctionCall ;
    sh:property [
        sh:path elixir:callsModule ;
        sh:not [ sh:hasValue elixir:IO ] ;
        sh:message "IO.inspect calls should be removed before production"@en ;
        sh:severity sh:Warning
    ] .

credo:ModuleDocViolation a sh:NodeShape ;
    sh:targetClass elixir:Module ;
    sh:property [
        sh:path elixir:hasModuleDoc ;
        sh:minCount 1 ;
        sh:message "Module lacks @moduledoc attribute"@en ;
        sh:severity sh:Info
    ] .
```

This formalization enables **reasoning over rule relationships** (e.g., "modules violating `ModuleDoc` often also violate `FunctionDoc`") and provides structured context for explanation generation.

---

## Training strategies that teach Credo compliance

Three complementary training approaches can embed Credo awareness into your model: **contrastive pre-training** to learn quality distinctions, **multi-task learning** to jointly optimize generation and classification, and **curriculum learning** to progressively introduce complexity.

### Contrastive learning with code smell pairs

The ContraCode framework (Jain et al., EMNLP 2021) demonstrates that contrastive pre-training significantly improves code understanding. For Credo-specific training, you generate pairs programmatically:

```elixir
defmodule CredoContrastiveGenerator do
  @doc "Generate clean/violating code pairs for contrastive training"
  
  def generate_pairs(clean_code, :io_inspect) do
    # Inject IO.inspect at random locations
    lines = String.split(clean_code, "\n")
    inject_line = Enum.random(0..length(lines)-1)
    
    violating = List.insert_at(lines, inject_line, "    |> IO.inspect(label: :debug)")
               |> Enum.join("\n")
    
    {clean_code, violating, "Credo.Check.Warning.IoInspect"}
  end
  
  def generate_pairs(clean_code, :nesting) do
    # Wrap existing conditions in additional layers
    ast = Code.string_to_quoted!(clean_code)
    nested_ast = increase_nesting(ast, 2)
    violating = Macro.to_string(nested_ast)
    
    {clean_code, violating, "Credo.Check.Refactor.Nesting"}
  end
end
```

The training objective uses **InfoNCE loss** to push clean code representations away from violating variants:

```elixir
defmodule ContrastiveLoss do
  import Nx.Defn
  
  defn info_nce_loss(anchor, positive, negatives, temperature \\ 0.07) do
    pos_sim = Nx.dot(anchor, positive) / temperature
    neg_sims = Nx.dot(anchor, Nx.transpose(negatives)) / temperature
    
    all_sims = Nx.concatenate([Nx.new_axis(pos_sim, 0), neg_sims])
    -pos_sim + Nx.log_sum_exp(all_sims)
  end
end
```

### Multi-task architecture for generation, classification, and explanation

A shared encoder with task-specific heads enables joint optimization across your three objectives:

```elixir
defmodule CredoAwareModel do
  def build(vocab_size, hidden_dim, num_rules) do
    # Shared transformer encoder
    encoder = Axon.input("code_tokens", shape: {nil, 512})
    |> Axon.embedding(vocab_size, hidden_dim)
    |> transformer_blocks(layers: 6, heads: 8)
    
    # Task 1: Code generation (causal LM head)
    generation_head = encoder
    |> Axon.dense(vocab_size, activation: :softmax, name: "gen_head")
    
    # Task 2: Rule violation classification
    classification_head = encoder
    |> Axon.global_average_pool()
    |> Axon.dense(num_rules, activation: :sigmoid, name: "cls_head")
    
    # Task 3: Explanation generation (seq2seq decoder)
    explanation_head = encoder
    |> cross_attention_decoder(hidden_dim)
    |> Axon.dense(vocab_size, activation: :softmax, name: "exp_head")
    
    Axon.container({generation_head, classification_head, explanation_head})
  end
end
```

Training balances objectives using **uncertainty weighting** (Kendall et al.) or **GradNorm** for gradient magnitude balancing. Research from CodeT5+ shows that mixture-of-objectives pre-training improves generalization across tasks.

### Curriculum learning from simple to complex rules

The "Curriculum Learning for Small Code Language Models" study (arXiv 2407.10194) establishes that **hybrid curriculum scheduling**—starting with simple examples and progressively adding harder ones without fully discarding previous stages—yields **2.3x improvement** on difficult code generation tasks versus non-curriculum approaches.

For Credo rules, structure the curriculum by pattern complexity:

| Stage | Rules | Difficulty Metric |
|-------|-------|-------------------|
| 1 | `FunctionNames`, `ModuleNaming`, `IoInspect` | Surface token patterns |
| 2 | `ModuleDoc`, `AliasOrder`, `MaxLineLength` | Local structural patterns |
| 3 | `Nesting`, `CyclomaticComplexity`, `CondStatements` | Cross-function analysis |
| 4 | `DuplicatedCode`, `AliasUsage`, Consistency checks | Corpus-level patterns |

```elixir
defmodule CurriculumDataLoader do
  def create_staged_stream(examples, difficulty_fn) do
    # Sort by difficulty score
    sorted = Enum.sort_by(examples, difficulty_fn)
    
    # Create expanding windows (hybrid approach)
    Stream.iterate({[], sorted}, fn {seen, remaining} ->
      {next_batch, rest} = Enum.split(remaining, batch_size())
      {seen ++ next_batch, rest}
    end)
    |> Stream.flat_map(fn {available, _} -> 
      Stream.cycle(available) |> Stream.take(epoch_size())
    end)
  end
  
  defp difficulty_fn(example) do
    credo_issues = run_credo_on(example.violating_code)
    
    # Weight by category and complexity
    Enum.reduce(credo_issues, 0, fn issue, acc ->
      case issue.category do
        :consistency -> acc + 4  # Hardest
        :design -> acc + 3
        :refactor -> acc + 2
        :readability -> acc + 1
        :warning -> acc + 1
      end
    end)
  end
end
```

---

## Enforcing Credo compliance during generation

Inference-time constraints provide a safety net when training alone is insufficient. Three approaches apply: **grammar-constrained decoding** for syntax, **monitor-guided decoding** for semantic rules, and **beam search with rejection** for complex validations.

### Grammar-constrained generation via incremental parsing

The **PICARD** algorithm (Scholak et al., EMNLP 2021) integrates incremental parsing with beam search, rejecting tokens that fail to parse at each step. For Elixir, this guarantees syntactic validity:

```elixir
defmodule IncrementalElixirParser do
  @doc "Returns valid next tokens given partial code"
  
  def valid_continuations(partial_code, vocabulary) do
    Enum.filter(vocabulary, fn token ->
      candidate = partial_code <> token
      case Code.string_to_quoted(candidate <> " end end end") do
        {:ok, _} -> true
        {:error, _} -> false
      end
    end)
  end
end
```

The **SynCode** framework achieves only **10% overhead** by pre-computing a DFA mask store from grammar terminals. This approach reduces syntax errors by **96%** when combined with state-of-the-art LLMs.

### Monitor-guided decoding for semantic constraints

**Monitor-Guided Decoding (MGD)** from Microsoft Research (NeurIPS 2023) provides a stateful interface between LLMs and static analysis. The key insight: trigger analysis only at specific code points (e.g., after `.` for member access) rather than every token.

```elixir
defmodule CredoMonitor do
  defstruct [:state, :partial_code, :active_checks]
  
  def update(%__MODULE__{} = monitor, new_token) do
    updated_code = monitor.partial_code <> new_token
    
    # Trigger analysis at semantic boundaries
    cond do
      String.ends_with?(new_token, "\n") ->
        issues = quick_line_check(updated_code)
        %{monitor | partial_code: updated_code, state: {:checked, issues}}
      
      String.ends_with?(new_token, "end") ->
        issues = quick_block_check(updated_code)
        %{monitor | partial_code: updated_code, state: {:checked, issues}}
      
      true ->
        %{monitor | partial_code: updated_code, state: :waiting}
    end
  end
  
  def mask_invalid_tokens(%__MODULE__{state: {:checked, issues}}, vocabulary) when issues != [] do
    # Apply negative bias to tokens that would worsen violations
    Enum.map(vocabulary, fn token ->
      if exacerbates_issue?(token, issues), do: -1000.0, else: 0.0
    end)
  end
  def mask_invalid_tokens(_, vocabulary), do: List.duplicate(0.0, length(vocabulary))
end
```

MGD achieves **19-25% improvement** in compilation rate across model scales from 350M to 175B parameters without retraining.

### Beam search with Credo rejection sampling

For complex rules that can't be checked incrementally, validate complete beam candidates:

```elixir
defmodule CredoBeamSearch do
  def decode_with_validation(model, prompt, opts \\ []) do
    beam_size = Keyword.get(opts, :beam_size, 5)
    max_rejections = Keyword.get(opts, :max_rejections, 3)
    
    candidates = generate_beam_candidates(model, prompt, beam_size)
    
    Enum.reduce_while(candidates, {:cont, []}, fn candidate, {:cont, rejected} ->
      case validate_with_credo(candidate) do
        {:ok, clean_code} -> 
          {:halt, {:ok, clean_code}}
        
        {:error, issues} when length(rejected) < max_rejections ->
          {:cont, {:cont, [{candidate, issues} | rejected]}}
        
        {:error, _} ->
          # All candidates rejected—attempt repair on best
          best = select_best_candidate(rejected)
          {:halt, {:repair_needed, best}}
      end
    end)
  end
  
  defp validate_with_credo(code) do
    source_file = %Credo.SourceFile{filename: "generated.ex", source: code}
    
    blocking_checks = [
      Credo.Check.Warning.IoInspect,
      Credo.Check.Warning.IExPry,
      Credo.Check.Warning.Dbg,
      Credo.Check.Readability.FunctionNames
    ]
    
    issues = Enum.flat_map(blocking_checks, &(&1.run(source_file, [])))
    
    if Enum.empty?(issues), do: {:ok, code}, else: {:error, issues}
  end
end
```

### Performance trade-offs in constrained decoding

| Approach | Overhead | Error Reduction | Use Case |
|----------|----------|-----------------|----------|
| Syntax constraints (SynCode) | ~10% | 96% syntax errors | Always-on |
| Type-directed (MGD) | Variable | 19-25% compilation | After "." triggers |
| Full Credo validation | ~50% | Variable | Post-generation |
| Beam rejection | 5x candidates | Depends on beam size | Critical code |

Research from "Let Me Speak Freely?" (2024) warns that **overly restrictive constraints can degrade reasoning**—models forced into strict formats during chain-of-thought generation perform worse. The recommendation: **loose constraints during reasoning, tight constraints for final output**.

---

## Generating natural language explanations of violations

Explanations must reference **specific Credo rule names**, provide **rationale grounded in Elixir idioms**, and suggest **actionable fixes**. Three techniques combine: chain-of-thought prompting, retrieval-augmented generation, and multi-task explanation heads.

### Chain-of-thought prompting for code quality reasoning

Structure prompts to decompose analysis into interpretable steps:

```elixir
defmodule ExplanationGenerator do
  def generate_explanation(code, issues, model_serving) do
    prompt = """
    Analyze this Elixir code for quality issues. Think step by step:
    
    1. IDENTIFY the code pattern at line #{issues |> hd() |> Map.get(:line_no)}
    2. EXPLAIN what #{issues |> hd() |> Map.get(:check)} detects
    3. DESCRIBE why this pattern is problematic in Elixir
    4. SUGGEST a specific fix with example code
    
    Code:
    ```elixir
    #{code}
    ```
    
    Detected issue: #{issues |> hd() |> Map.get(:message)}
    """
    
    Nx.Serving.batched_run(model_serving, prompt)
  end
end
```

Research on chain-of-thought for code (ICLR 2025) shows that **reasoning prompts improve self-repair ability** when adapted to problem difficulty. Fine-tuning with optimal CoT configuration allows models to internalize the reasoning pattern.

### Retrieval-augmented generation with Credo documentation

Index all Credo rule documentation and explanations for retrieval:

```elixir
defmodule CredoDocRetriever do
  @doc_embeddings :persistent_term.get(:credo_doc_embeddings)
  
  def retrieve_context(rule_name, k \\ 3) do
    query_embedding = embed_text("Explain #{rule_name} Credo rule")
    
    @doc_embeddings
    |> Enum.map(fn {doc_text, embedding, metadata} ->
      {cosine_similarity(query_embedding, embedding), doc_text, metadata}
    end)
    |> Enum.sort_by(&elem(&1, 0), :desc)
    |> Enum.take(k)
    |> Enum.map(&elem(&1, 1))
    |> Enum.join("\n\n")
  end
  
  def augmented_prompt(code, issues) do
    rule_name = issues |> hd() |> Map.get(:check) |> Module.split() |> Enum.join(".")
    context = retrieve_context(rule_name)
    
    """
    Using this documentation about the #{rule_name} rule:
    
    #{context}
    
    Explain why the following code violates this rule and how to fix it:
    
    ```elixir
    #{code}
    ```
    """
  end
end
```

RAG provides **up-to-date rule documentation** without retraining, **citations to specific rule explanations**, and **reduced hallucination** by grounding responses in actual Credo docs.

### Explanation evaluation metrics

| Metric | What It Measures | Recommendation |
|--------|------------------|----------------|
| BLEU-4 | N-gram overlap | Limited correlation with quality |
| CodeBLEU | Syntax + dataflow matching | Better for code-specific text |
| ChrF | Character-level F-score | Recommended by recent studies |
| Human: Accuracy | Does explanation match actual violation? | Essential |
| Human: Actionability | Can developer fix code from explanation? | Essential |

The "Out of the BLEU" study (Evtikhiev et al., 2023) found that **no automated metric perfectly correlates with human judgment** for code explanations. Use ChrF/CodeBLEU for development iteration, but validate with human evaluation before deployment.

---

## System architecture for Credo-aware generation

The complete pipeline integrates four components: **programmatic Credo invocation**, **Nx.Serving for batched inference**, **feedback loop orchestration**, and **ontology integration**.

### Calling Credo programmatically from Elixir

```elixir
defmodule CredoRunner do
  @doc "Run specific checks on a code string"
  
  def check_code(code_string, checks \\ default_checks()) do
    with {:ok, _ast} <- Code.string_to_quoted(code_string) do
      source_file = %Credo.SourceFile{
        filename: "generated_#{:erlang.unique_integer()}.ex",
        source: code_string
      }
      
      issues = Enum.flat_map(checks, fn check ->
        check.run(source_file, check.param_defaults())
      end)
      
      {:ok, issues}
    else
      {:error, {line, error, token}} ->
        {:syntax_error, %{line: line, error: error, token: token}}
    end
  end
  
  defp default_checks do
    [
      Credo.Check.Readability.FunctionNames,
      Credo.Check.Readability.ModuleNaming,
      Credo.Check.Readability.ModuleDoc,
      Credo.Check.Warning.IoInspect,
      Credo.Check.Warning.IExPry,
      Credo.Check.Warning.Dbg,
      Credo.Check.Refactor.Nesting
    ]
  end
end
```

### Complete generate-check-explain pipeline

```elixir
defmodule CredoAwareCodeGen do
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    # Load model
    {:ok, model_info} = Bumblebee.load_model({:hf, opts[:model_name]})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, opts[:model_name]})
    
    serving = Bumblebee.Text.generation(model_info, tokenizer,
      max_new_tokens: 500,
      compile: [batch_size: 4]
    )
    
    {:ok, serving_pid} = Nx.Serving.start_link(serving: serving, name: :code_gen_serving)
    
    {:ok, %{serving: serving_pid, max_attempts: opts[:max_attempts] || 3}}
  end
  
  def generate(prompt, opts \\ []) do
    GenServer.call(__MODULE__, {:generate, prompt, opts}, :infinity)
  end
  
  def handle_call({:generate, prompt, opts}, _from, state) do
    result = generate_with_feedback_loop(prompt, state.max_attempts)
    {:reply, result, state}
  end
  
  defp generate_with_feedback_loop(prompt, attempts_remaining, history \\ [])
  
  defp generate_with_feedback_loop(_prompt, 0, history) do
    # Return best attempt with explanation
    {best_code, issues} = select_best_attempt(history)
    explanation = generate_explanation(best_code, issues)
    {:partial, best_code, issues, explanation}
  end
  
  defp generate_with_feedback_loop(prompt, attempts, history) do
    # Generate code
    %{results: [%{text: code}]} = Nx.Serving.batched_run(:code_gen_serving, prompt)
    
    # Check with Credo
    case CredoRunner.check_code(code) do
      {:ok, []} ->
        # Clean code—generate positive explanation
        explanation = "This code follows all Credo guidelines for #{summarize_checks()}."
        {:ok, code, explanation}
      
      {:ok, issues} ->
        # Violations found—refine prompt and retry
        refined_prompt = build_repair_prompt(prompt, code, issues)
        generate_with_feedback_loop(refined_prompt, attempts - 1, [{code, issues} | history])
      
      {:syntax_error, error} ->
        # Syntax error—different repair strategy
        refined_prompt = build_syntax_repair_prompt(prompt, code, error)
        generate_with_feedback_loop(refined_prompt, attempts - 1, history)
    end
  end
  
  defp build_repair_prompt(original_prompt, code, issues) do
    issue_descriptions = Enum.map(issues, fn issue ->
      "- Line #{issue.line_no}: #{issue.message} (#{issue.check |> Module.split() |> List.last()})"
    end)
    
    """
    #{original_prompt}
    
    Previous attempt had these Credo violations:
    #{Enum.join(issue_descriptions, "\n")}
    
    Generate corrected code that avoids these issues:
    """
  end
end
```

### Integration with ontology-augmented training

Your existing RDF/OWL framework can incorporate Credo semantics:

```elixir
defmodule OntologyCredoIntegration do
  @doc "Enrich training examples with ontological context"
  
  def augment_training_example(code, credo_issues) do
    # Parse code to extract semantic entities
    entities = extract_ontology_entities(code)
    
    # Map Credo issues to ontology violations
    ontology_violations = Enum.map(credo_issues, fn issue ->
      %{
        rule: credo_check_to_shacl(issue.check),
        entity: find_violating_entity(entities, issue),
        severity: category_to_severity(issue.category)
      }
    end)
    
    # Create enriched training record
    %{
      code: code,
      credo_issues: credo_issues,
      ontology_entities: entities,
      ontology_violations: ontology_violations,
      # For multi-task learning
      generation_target: code,
      classification_target: issues_to_binary_vector(credo_issues),
      explanation_target: generate_explanation_text(credo_issues)
    }
  end
  
  defp credo_check_to_shacl(Credo.Check.Warning.IoInspect), do: "credo:IoInspectViolation"
  defp credo_check_to_shacl(Credo.Check.Readability.ModuleDoc), do: "credo:ModuleDocViolation"
  # ... map all relevant checks
end
```

---

## Measuring success: evaluation frameworks

Evaluating a Credo-aware code generation model requires metrics across three dimensions: **functional correctness**, **quality compliance**, and **explanation utility**.

### Credo violation detection accuracy

```elixir
defmodule CredoEvaluator do
  @doc "Measure model's ability to generate Credo-compliant code"
  
  def evaluate_generation(model, test_prompts) do
    results = Enum.map(test_prompts, fn prompt ->
      code = generate_code(model, prompt)
      {:ok, issues} = CredoRunner.check_code(code)
      
      %{
        prompt: prompt,
        code: code,
        issue_count: length(issues),
        categories: Enum.frequencies_by(issues, & &1.category),
        compiles: compiles?(code),
        passes_tests: passes_tests?(code, prompt.test_cases)
      }
    end)
    
    %{
      credo_clean_rate: Enum.count(results, & &1.issue_count == 0) / length(results),
      avg_issues: Enum.map(results, & &1.issue_count) |> mean(),
      compile_rate: Enum.count(results, & &1.compiles) / length(results),
      test_pass_rate: Enum.count(results, & &1.passes_tests) / length(results),
      issues_by_category: aggregate_categories(results)
    }
  end
end
```

### A/B comparison framework

Compare model variants to isolate the impact of Credo training:

| Model Variant | Training Data | Inference Strategy |
|--------------|---------------|-------------------|
| Baseline | Standard Elixir corpus | Unconstrained |
| +Contrastive | Corpus + contrastive pairs | Unconstrained |
| +Multi-task | Corpus + contrastive + explanations | Unconstrained |
| +Curriculum | Staged curriculum training | Unconstrained |
| +Constrained | Any training | Grammar constraints |
| +Full | All training enhancements | Constrained + repair |

Key metrics to track:
- **Credo clean rate**: % of generations with zero violations
- **Pass@k**: % passing all tests within k attempts
- **Violation reduction**: % fewer issues vs. baseline
- **Generation latency**: Time to produce compliant code
- **Explanation accuracy**: Human-rated correctness of explanations

### Human evaluation protocol for explanation quality

For explanation evaluation, recruit Elixir developers to rate generated explanations on:

1. **Accuracy** (1-5): Does the explanation correctly identify the violation?
2. **Completeness** (1-5): Does it cover all relevant aspects?
3. **Actionability** (1-5): Could a developer fix the code using this explanation?
4. **Clarity** (1-5): Is the explanation easy to understand?
5. **Rule alignment** (binary): Does it correctly reference the Credo rule name?

Target inter-annotator agreement (Cohen's κ > 0.6) before aggregating scores.

---

## Conclusion

Building a Credo-aware Elixir code generation model is achievable with current ML techniques. The most impactful interventions combine **contrastive pre-training** using programmatically generated violation pairs, **multi-task learning** that jointly optimizes generation and classification, and **monitor-guided decoding** that triggers Credo checks at semantic boundaries rather than every token.

Three key architectural decisions maximize practical impact:

1. **Prioritize high-amenability rules**: Focus training on Readability and Warning checks that involve surface patterns before tackling Refactor and Consistency rules requiring deeper analysis.

2. **Layer constraint strictness**: Apply lightweight syntax constraints always, semantic checks at triggers, and full Credo validation as post-generation repair rather than blocking generation.

3. **Ground explanations in documentation**: RAG with indexed Credo docs provides accurate, rule-specific explanations without requiring the model to memorize rule semantics.

The integration with your existing ontology framework is natural—SHACL shapes can express Credo rules as formal constraints, enabling reasoning about rule relationships and consistent explanation generation. Start with the 10-15 most commonly violated rules, establish baseline metrics, then expand coverage based on measured impact.
