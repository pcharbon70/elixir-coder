# Elixir Graph

Ontology-augmented code generation for Elixir combining RDF/OWL semantic annotations with neural language models to produce code that is functionally correct, idiomatic, secure, and well-tested.

## Project Goals

This project builds a code generation model that leverages structured knowledge about Elixir—OTP behaviors, type specifications, module relationships, code quality rules, and security patterns—to compensate for the relatively small Elixir training corpus compared to languages like Python or JavaScript.

Research on knowledge-enhanced language models (ERNIE, K-BERT, GraphCodeBERT) demonstrates that structured knowledge injection can improve code generation by **7-25%** on semantic understanding tasks. The greatest gains appear in:

- **Type inference** (+25% accuracy)
- **OTP pattern recognition** (+18% pass@1)
- **Security vulnerability prevention** (35-50% F1 improvement with contrastive learning)
- **Code quality compliance** (2.3x improvement on difficult tasks with curriculum learning)
- **Clarification-driven generation** (+5-10% pass@1 when asking one well-chosen question)

## Architecture

### Linearized Triple Representations

Rather than complex graph neural network architectures requiring substantial custom implementation, this project uses linearized triples that standard transformers can process directly:

```
[CODE] def handle_call(request, from, state) [/CODE]
[ONTO] <module>GenServer</module> <pattern>handle_call</pattern> <type>sync_request</type> [/ONTO]
```

This approach maintains compatibility with existing transformer architectures while preserving ontological structure. Graph embeddings via RDF2Vec or OWL2Vec* can be precomputed and incorporated as additional embedding dimensions.

### Ontology Foundation

Four ontology files define Elixir semantics (available at [pcharbon70/elixir-ontologies](https://github.com/pcharbon70/elixir-ontologies)):

| File | Purpose |
|------|---------|
| `elixir-core.ttl` | Core language primitives, types, and operators |
| `elixir-otp.ttl` | OTP behaviours (GenServer, Supervisor, Agent, Task) |
| `elixir-structure.ttl` | Module hierarchy, function signatures, dependencies |
| `elixir-shapes.ttl` | SHACL validation shapes (extending to Credo and security rules) |

### Multi-Task Learning Architecture

The model uses a shared encoder-decoder transformer (CodeT5-style, 125M-350M parameters) with task-specific heads:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Shared Transformer Encoder                           │
│                       (Code + Ontology Embeddings)                           │
└─────────────────────────────────────────────────────────────────────────────┘
        │            │            │            │            │            │
        ▼            ▼            ▼            ▼            ▼            ▼
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│   Code   │  │ Quality  │  │ Security │  │  Test    │  │Clarify   │  │Explanation│
│   Gen    │  │  (Credo) │  │(Sobelow) │  │   Gen    │  │ Question │  │   Gen    │
└──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘
```

## Core Capabilities

### 1. Code Generation with Ontology Augmentation

Standard code generation enhanced with semantic knowledge from RDF/OWL ontologies, enabling better understanding of OTP patterns, type relationships, and Elixir idioms.

### 2. Interactive Clarification

Before generating code for ambiguous requirements, the model can ask a single clarifying question. The system:

- **Detects ambiguity** by generating multiple samples and measuring behavioral divergence
- **Quantifies uncertainty** using semantic entropy over functional clusters
- **Generates targeted questions** using Expected Value of Perfect Information ranking
- **Conditions generation** on user answers via cross-attention mechanisms

Example triggers for clarification:
- "Process orders" → "Should failures raise exceptions or return `{:error, reason}` tuples?"
- "Store state" → "Should this use GenServer (complex sync) or Agent (simple read/write)?"
- "Handle requests" → "What fields does the User schema contain?"

### 3. Test Generation with Mutation Feedback

The model generates high-quality tests using execution feedback from Muzak mutation testing:

- **Pre-training objectives**: Masked span prediction, fill-in-middle, assert completion
- **Execution feedback**: Muzak mutation scores as RL rewards—tests that kill more mutants get higher rewards
- **Specialized adapters**: Lorax LoRA adapters for ExUnit, StreamData (property tests), and LiveViewTest

Target test distribution: 60% ExUnit, 25% StreamData, 15% LiveViewTest

### 4. Quality and Security Enforcement

Multi-task training on Credo (83+ checks) and Sobelow (30+ vulnerability types) with constrained decoding at inference time.

## Training Pipeline

### Data Sources

- **Minimum viable corpus**: ~10,000 annotated Elixir functions with ontology coverage
- **Primary sources**: Hex.pm packages (~17,000+), GitHub Elixir repos (~25,000-50,000)
- **Quality filtering**: Must have tests, documentation, pass Credo, recent maintenance
- **Augmentation target**: 50,000+ samples via synthetic generation and contrastive pairs

### Training Objectives

1. **Code Generation** - Masked language modeling with type-specific masking
2. **Quality Compliance** - Credo rule violation classification (5 categories)
3. **Security Detection** - Sobelow finding classification (mapped to CWE)
4. **Test Generation** - Code-to-test and test-to-code bidirectional training
5. **Clarification** - Ask-or-proceed decision + question generation
6. **Explanation Generation** - Natural language grounded in documentation

### Curriculum Learning Schedule

| Phase | Epochs | Focus |
|-------|--------|-------|
| 1 | 1-10 | Code-only MLM |
| 2 | 11-30 | Code + simple ontology annotations |
| 3 | 31-50 | Code + full multi-hop ontology graphs |
| 4 | 51+ | Complex examples + clarification training |

### Reinforcement Learning with Execution Feedback

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Generate   │────▶│  Run Muzak   │────▶│   Compute    │
│    Tests     │     │  Mutations   │     │   Reward     │
└──────────────┘     └──────────────┘     └──────────────┘
                                                 │
┌──────────────┐     ┌──────────────┐            │
│   Update     │◀────│   Policy     │◀───────────┘
│   Model      │     │   Gradient   │
└──────────────┘     └──────────────┘
```

Reward = mutation kill rate (tests that catch more bugs score higher)

## Inference Pipeline

### Clarification-First Flow

```
┌─────────┐     ┌───────────┐     ┌─────────┐
│ Prompt  │────▶│  Analyze  │────▶│Ambiguous│───Yes──▶ Ask Question ──▶ Get Answer
└─────────┘     │ Ambiguity │     │    ?    │                              │
                └───────────┘     └─────────┘                              │
                                       │                                   │
                                      No                                   │
                                       │                                   │
                                       ▼                                   ▼
                              ┌─────────────────┐◀──────────────────────────┘
                              │ Generate Code   │
                              │ (with context)  │
                              └─────────────────┘
```

### Constrained Decoding

| Layer | Approach | Overhead | Error Reduction |
|-------|----------|----------|-----------------|
| Syntax | Grammar-constrained via DFA mask stores | ~10% | 96% syntax errors |
| Semantic | Monitor-guided decoding at trigger points | Variable | 19-25% compilation |
| Quality/Security | Beam search with rejection sampling | 5x candidates | Depends on beam size |

### Generate-Check-Repair Loop

```
┌──────────┐     ┌─────────┐     ┌──────────┐
│ Generate │────▶│  Check  │────▶│  Clean?  │───Yes──▶ Return
└──────────┘     │ (Credo/ │     └──────────┘
                 │Sobelow) │           │
                 └─────────┘           No
                                       │
                 ┌─────────┐           ▼
                 │ Repair  │◀────┌──────────┐
                 │ Prompt  │     │ Refine & │
                 └─────────┘────▶│  Retry   │
                                 └──────────┘
```

## Tech Stack

| Component | Library | Purpose |
|-----------|---------|---------|
| Neural Networks | Axon | Custom layers, graph attention, transformers |
| Tokenization | Bumblebee + custom | BPE with Elixir-specific symbols (`|>`, `:ok`, `@spec`) |
| Acceleration | EXLA | GPU/TPU backend |
| LoRA Adaptation | Lorax | Parameter-efficient fine-tuning for test type specialization |
| RDF Processing | rdf-ex | Ontology parsing and manipulation |
| Code Quality | Credo | 83+ checks, programmatic API |
| Security | Sobelow | 30+ vulnerability types, JSON output |
| Mutation Testing | Muzak | Execution feedback for test quality |

### Model Sizing

| Configuration | Parameters | Memory | Use Case |
|---------------|------------|--------|----------|
| Base model | 125M | ~1-2 GB | Development, fast iteration |
| Full model | 350M | ~4-6 GB | Production deployment |
| LoRA adapters | 2-4M each | ~4-10 MB | Test type specialization |

### Hybrid Architecture

- **Python**: Graph preprocessing, embedding generation (pyRDF2Vec, OWL2Vec*)
- **Elixir**: Training loop, inference, deployment via Nx.Serving

## Evaluation

### Primary Metrics

- **pass@k**: Probability that at least one of k samples passes all tests
- **secure-pass@k**: Code that is both secure AND functionally correct
- **Credo clean rate**: Percentage with zero quality violations
- **Mutation score**: Percentage of Muzak mutations killed by generated tests
- **ΔPass@1**: Improvement from clarification vs. direct generation

### Expected Improvements

| Dimension | Baseline | With Full System | Expected Δ |
|-----------|----------|------------------|------------|
| pass@1 (basic patterns) | ~65% | ~72% | +7% |
| pass@1 (OTP-specific) | ~40% | ~58% | +18% |
| pass@1 (with clarification) | ~62% | ~70% | +8% |
| Type inference accuracy | ~45% | ~70% | +25% |
| Test mutation score | ~50% | ~75% | +25% |

## Project Status

**Current Phase**: Research and planning

### Research Documentation

```
notes/research/
├── 1.01-ontology-augmented-code-generation/
│   └── 1.01.1-ontology-augmented-code-generation    # Core architecture
├── 1.02-credo-rules/
│   └── 1.02.1-respecting-credo-rules.md             # Code quality integration
├── 1.03-code-security-enhancement/
│   └── 1.03.1-code-security-enhancement.md          # Security via Sobelow
├── 1.04-interactive-code-generator/
│   └── 1.04.1-code-generator-with-intelligent-clarification.md  # Clarification system
└── 1.05-high-quality-tests/
    └── 1.05.1-training-high-quality-paired-tests.md # Test generation with Muzak
```

## Research Foundation

| Paper/System | Contribution |
|--------------|--------------|
| GraphCodeBERT | Data flow graph integration, joint pre-training |
| K-BERT | Knowledge triple injection without retraining |
| CodeT5/CodeT5+ | Encoder-decoder architecture, multi-task pre-training |
| TyFlow | Type-constrained generation via synthesis rules |
| ClarifyGPT | Ambiguity detection via code consistency checking |
| SpecFix | Multi-sample divergence for requirement clarification |
| Monitor-Guided Decoding | Static analysis in the decoding loop |
| SynCode | Grammar-constrained generation via DFA masks |
| VulLLM | Multi-task learning for vulnerability detection |
| CodeRL | Execution feedback for code generation |
| Lorax | LoRA implementation for Axon |
| Muzak | Mutation testing for Elixir |

## License

TBD
