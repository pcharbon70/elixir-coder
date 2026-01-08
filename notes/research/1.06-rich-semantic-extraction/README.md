# 1.06 Rich Semantic Extraction for Elixir Code Generation

## Executive Summary

The elixir-ontologies project provides two distinct approaches for extracting semantic information from Elixir code:

1. **Pre-generated .ttl files** (13,597 Hex.pm packages) - Simplified subset, fast lookups
2. **Full Pipeline API** - Complete semantic extraction including guards, patterns, types, callbacks

For training an Elixir code generation model, the **full pipeline offers significant advantages** that directly translate to better code quality and fewer hallucinations.

---

## Current Gap: Pre-generated .ttl Files

The `.ttl/` directory contains 13,597 pre-generated ontology files, but these capture only a simplified subset:

```turtle
<https://example.org/code#MyModule/my_func/2>
    a struct:PublicFunction ;
    struct:arity "2"^^xsd:nonNegativeInteger ;
    struct:belongsTo <https://example.org/code#MyModule> ;
    struct:functionName "my_func" .
```

### What's Included

| Feature | Training Value |
|---------|----------------|
| Module names | Low - namespace only |
| Function name + arity | Medium - signature only |
| Public/Private visibility | Low - API boundary |
| Source location (file:line) | None - metadata |
| Module dependencies | Medium - import graph |
| Module docstrings | Medium - high-level intent |

### What's Missing

| Missing Feature | Why It Matters for Training |
|-----------------|----------------------------|
| **Function bodies** | Primary training signal for syntax, idioms, patterns |
| **Function docstrings** | Intent ↔ implementation mapping for instruction tuning |
| **@spec annotations** | Type-aware generation, pipe data flow correctness |
| **@callback definitions** | OTP behaviour implementation patterns |
| **Guard expressions** | `when is_integer(x) and x > 0` - guard-safe code |
| **Pattern parameters** | `%User{name: name}` - destructuring idioms |
| **Function clause ordering** | First-match-wins semantics |
| **Default parameter values** | Function call variants |
| **Type expression trees** | Complex types like `keyword(String.t()) | [integer()]` |

---

## Full Pipeline: What Becomes Available

Using `ElixirOntologies.Pipeline.analyze_and_build/2` on downloaded source code unlocks rich semantic extraction.

### Guard Clause Extraction

The `ElixirOntologies.Extractors.Guard` module captures:

```elixir
# Source code:
def process(x) when is_integer(x) and x > 0 do
  # ...
end

# Extracted:
%Guard{
  expression: {:and, [], [{:is_integer, [], [{:x, [], nil}]}, {:>, [], [{:x, [], nil}, 0]}]},
  combinator: :and,
  guard_functions: [:is_integer, :>],
  metadata: %{
    has_type_check: true,
    has_comparison: true
  }
}
```

**Training Advantage**: The model learns which expressions are guard-safe, preventing generation of invalid guards like `when String.length(x) > 0`.

### Parameter Pattern Extraction

The `ElixirOntologies.Extractors.Parameter` module captures:

```elixir
# Source code:
def handle(%User{name: name, age: age} = user, opts \\ []) do
  # ...
end

# Extracted parameters:
[
  %Parameter{
    name: nil,
    type: :pattern,
    metadata: %{pattern_type: :struct}
    # Full struct pattern: %User{name: name, age: age} = user
  },
  %Parameter{
    name: :opts,
    type: :default,
    default_value: []
  }
]
```

**Training Advantage**: The model learns idiomatic destructuring patterns - when to use struct patterns vs tuple patterns vs simple variables.

### Type Expression Extraction

The `ElixirOntologies.Extractors.TypeExpression` module captures:

```elixir
# @spec keyword(String.t()) | [integer()] | map()

# Extracted:
%TypeExpression{
  type: :union,
  alternatives: [
    %{type: :function, name: :keyword, args: [%{type: :basic, name: :String}]},
    %{type: :list, inner: %{type: :basic, name: :integer}},
    %{type: :map}
  ]
}
```

**Training Advantage**: The model learns type-directed code generation - given `@spec foo(keyword(String.t()))`, generate `def foo(opts) when is_list(opts)`.

### Callback Definition Extraction

The `ElixirOntologies.Builders.BehaviourBuilder` module captures:

```elixir
# Source:
defmodule GenServer do
  @callback init(args :: term()) ::
    {:ok, state :: term()} |
    {:ok, state :: term(), timeout :: timeout() | :hibernate} |
    :ignore
end

# Extracted:
%Callback{
  name: :init,
  arity: 1,
  params: [%{name: :args, type: :term}],
  returns: %Union{
    alternatives: [
      {:ok, :state},
      {:ok, :state, :timeout_or_hibernate},
      :ignore
    ]
  }
}
```

**Training Advantage**: The model learns the contract between behaviour definition and implementation, reducing "missing callback" errors.

---

## Comparative Analysis

### Example: Pattern Matching Function

Consider this idiomatic Elixir function:

```elixir
defmodule UserService do
  @spec get_user(id :: integer() | String.t()) ::
    {:ok, User.t()} |
    {:error, :not_found}
  def get_user(id) when is_integer(id) do
    # fetch by ID
  end

  def get_user(id) when is_binary(id) do
    # fetch by UUID string
  end
end
```

#### What Pre-generated .ttl Captures

```turtle
<UserService/get_user/1>
    a struct:PublicFunction ;
    struct:arity "1"^^xsd:nonNegativeInteger ;
    struct:functionName "get_user" .
```

**Training Signal**: Minimal - just knows function exists with arity 1.

#### What Full Pipeline Captures

```turtle
# Clause 1
<UserService/get_user/1/clause/0>
    a struct:FunctionClause ;
    struct:clauseOrder "1"^^xsd:positiveInteger ;
    struct:hasHead _:head1 ;
    struct:hasBody _:body1 .

_:head1
    struct:hasParameter [
        a struct:PatternParameter ;
        struct:patternType :simple ;
        struct:parameterName "id"
    ] ;
    core:hasGuard [
        a core:GuardClause ;
        core:hasExpression [
            a core:Guard ;
            core:guardFunction :is_integer
        ]
    ] .

# Type specification
<UserService/get_user/1>
    struct:hasSpec [
        a struct:FunctionSpec ;
        struct:params [
            core:TypeVariable "id" ;
            core:UnionType [
                core:BasicType :integer ,
                core:BasicType :String
            ]
        ] ;
        struct:returns [
            core:UnionType [
                core:TupleType [:ok, :User] ,
                core:TupleType [:error, :not_found]
            ]
        ]
    ] .
```

**Training Signal**: Rich - learns:
1. Multi-clause pattern matching with guards
2. Type-directed dispatch (`is_integer` vs `is_binary`)
3. Union types in both params and return values
4. Tagged tuple return convention

---

## Training Architecture Implications

### Current Design (Phase 1 Planning)

```
[CODE] def get_user(id) when is_integer(id) do... [/CODE]
[ONTO] <module>UserService</module> <function>get_user/1</function> [/ONTO]
```

**Limitation**: Ontology annotation only signals module/function identity.

### Enhanced Design with Full Pipeline

```
[CODE] def get_user(id) when is_integer(id) do... [/CODE]
[ONTO]
  <function>get_user/1</function>
  <clause>1</clause>
  <guard>is_integer(id)</guard>
  <spec>@spec get_user(integer() | String.t()) :: {:ok, User.t()} | {:error, :not_found}</spec>
  <pattern>simple_pattern:id</pattern>
  <return_type>tagged_tuple</return_type>
[/ONTO]
```

**Advantage**: Model learns the semantic relationship between guards, types, and patterns.

---

## Implementation Impact

### Phase 1: Data Collection Updates

**Current (Section 1.2)**: Download Hex.pm tarballs → Extract to `data/raw/hex/`

**Add**:
```
1.2.7 Run elixir-ontologies full pipeline on downloaded packages
- [ ] 1.2.7.1 Implement `ElixirCoder.Data.Hex.analyze_with_ontology/2`
- [ ] 1.2.7.2 Use `ElixirOntologies.Pipeline.analyze_and_build/2`
- [ ] 1.2.7.3 Extract guards, patterns, types, callbacks to enriched JSON
- [ ] 1.2.7.4 Store: `data/processed/enriched/{package}.json`
- [ ] 1.2.7.5 Include full RDF graph in quad store for SPARQL queries
```

### Phase 5: Multi-Task Training Updates

**Enhanced Code Generation Head**:

Input includes:
- Source code tokens
- Guard expressions (linearized)
- Pattern types (encoded)
- Type specifications (linearized)
- Callback requirements (if implementing behaviour)

Loss function weights:
- Code likelihood: 1.0
- Guard validity: 0.3 (penalize non-guard-safe expressions in guards)
- Type consistency: 0.2 (penalize violations of @spec)

---

## Quantitative Benefits

### Estimated Coverage Improvement

| Metric | Pre-generated .ttl | Full Pipeline |
|--------|-------------------|---------------|
| Functions with semantic info | Name + arity only | Guards + patterns + types |
| Type coverage | 0% (not extracted) | ~40% of functions have @spec |
| Guard coverage | 0% (not extracted) | ~25% of clauses have guards |
| Pattern coverage | 0% (not extracted) | ~60% of parameters use patterns |
| Callback coverage | 0% (not extracted) | 100% of behaviours |

### Expected Model Performance Impact

| Metric | Current Target | With Full Pipeline |
|--------|----------------|-------------------|
| Guard validity | N/A | >95% guard-safe code |
| Type consistency | N/A | >90% @spec compliant |
| Pattern matching quality | Baseline | +15% pass@1 |
| OTP behaviour correctness | Baseline | +20% fewer callback errors |

---

## Computational Trade-offs

### Storage Requirements

| Component | Estimated Size | Notes |
|-----------|----------------|-------|
| Pre-generated .ttl files | ~75 MB (73.8M triples) | Already available |
| Enriched JSON (full extraction) | ~500 MB - 1 GB | Guards, patterns, types |
| Source code (downloaded) | ~5-10 GB | Primary training data |
| Full RDF graphs (all packages) | ~5-10 GB | Complete semantic model |

### Processing Time

| Operation | Time (estimated) |
|-----------|------------------|
| Load pre-generated .ttl to quad store | ~5 minutes |
| Download 10K Hex.pm packages | ~2-4 hours |
| Full pipeline extraction (10K packages) | ~10-20 hours |
| SPARQL query (ontology lookup) | <100ms (indexed) |

**Recommendation**: Extract once, cache in quad store, query during training.

---

## Research Questions

1. **Guard learning**: Does explicit guard annotation improve guard-safe generation?
   - A/B test: Train with and without guard annotations
   - Metric: Percentage of generated guards that are guard-safe

2. **Type-directed generation**: Does @spec annotation improve type consistency?
   - A/B test: Train with and without type specifications
   - Metric: Type consistency with provided @spec

3. **Pattern transfer**: Do pattern annotations improve idiomatic destructuring?
   - Evaluation: Human rating of generated pattern matching code
   - Baseline: Model trained without pattern annotations

4. **Callback grounding**: Does callback annotation reduce implementation errors?
   - Metric: Missing callback errors in generated GenServer implementations
   - Baseline: Model trained without callback definitions

---

## Related Work

| Paper | Technique | Relevance |
|-------|-----------|-----------|
| GraphCodeBERT (2020) | Data flow graphs | Similar: our guard/pattern graphs |
| K-BERT (2020) | Knowledge triple injection | Similar: our ontology linearization |
| CodeT5 (2021) | Encoder-decoder for code | Base architecture |
| SynCode (2023) | Grammar-constrained generation | Complementary: guard validity |
| VulLLM (2024) | Multi-task vulnerability detection | Parallel: our security head |

**Our Contribution**: Language-specific semantic extraction (Elixir guards, patterns, OTP) not captured by generic AST approaches.

---

## Next Steps

1. **Prototype**: Run full pipeline on 100 packages → Analyze extraction quality
2. **Benchmark**: Compare model trained with/without rich semantics
3. **Integrate**: Update Phase 1 planning to include full pipeline extraction
4. **Evaluate**: Establish metrics for guard validity, type consistency

---

## Conclusion

The pre-generated .ttl files provide fast lookup for package-level metadata, but **lack the semantic richness needed for high-quality code generation**. By leveraging the full elixir-ontologies pipeline on downloaded source code, we gain:

1. **Guard expressions** - Teach guard-safe code generation
2. **Pattern parameters** - Teach idiomatic destructuring
3. **@spec annotations** - Teach type-directed generation
4. **@callback definitions** - Teach OTP behaviour implementation
5. **Function clause structure** - Teach multi-clause pattern matching

This semantic grounding directly addresses common failure modes in code generation: invalid guards, non-idiomatic patterns, type mismatches, and missing callbacks. The computational cost is justified by the expected improvement in code quality and reduction in hallucinations.
