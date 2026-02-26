# Elixir LLM Implementation Plan

## Executive Summary

This plan outlines the implementation of a domain-specific large language model for Elixir code generation, augmented by RDF/OWL ontologies describing the language's semantics, OTP behaviors, and best practices. The implementation spans 7 phases, progressing from data collection through model training to production deployment.

## Phase Overview

| Phase | Focus | Key Deliverables |
|-------|-------|------------------|
| 1 | Data Collection & Preparation | Hex.pm corpus, GitHub repos, mixed code+NL corpus from HexDocs + Hex.pm repo artifacts (Elixir-only), provenance-aware annotated dataset, decontamination/PII filters |
| 2 | Tokenizer & Vocabulary | Custom BPE tokenizer with Elixir symbols, 32K vocabulary |
| 3 | Model Architecture | Encoder-decoder transformer using Edifice APIs when available (Axon fallback), 125M-350M params |
| 4 | Training Infrastructure | Data pipelines, multi-objective loss, curriculum learning, Edifice-aware backend adapters |
| 5 | Multi-Task Training | Code, quality, security, tests, clarification, explanation, OTP policy heads, instruction-tuning datasets (HexDocs + Hex.pm repo artifacts), staged NL/code mix profiles |
| 6 | Inference Pipeline | Serving, constrained decoding, generate-check-repair loop, policy compliance checks, Edifice-aware execution path |
| 7 | Evaluation & Production | Benchmarks, optimization, deployment, hard-gated OTP policy metrics, prompt-following/contamination slices, Edifice-vs-custom parity gates |

## Architecture Overview

**Policy Behavior Axis**: Across training and inference, code is evaluated against two contexts: supervised internals (let invariant failures crash under OTP supervision) and boundary handling (explicitly handle expected external failures).
**Implementation Axis**: Prefer Edifice APIs for model blocks, adapters, and optimization utilities where coverage exists; use custom Axon/Nx modules only for unsupported paths.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Elixir Code Generation System                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                Inference Pipeline                               │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │  Ambiguity  │───▶│ Constrained │───▶│  Generate-  │───▶│ Explanation │      │
│  │  Detection  │    │  Decoding   │    │   Check-    │    │  Generation │      │
│  └─────────────┘    └─────────────┘    │   Repair     │    └─────────────┘      │
│                                         └─────────────┘                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                           Multi-Task Transformer Model                          │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │              Shared Encoder-Decoder (Edifice + Axon fallback)            │    │
│  │                    CodeT5-style, 125M-350M params                       │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
│          │               │               │               │               │      │
│          ▼               ▼               ▼               ▼               ▼      │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐   │
│  │   Code    │  │  Quality  │  │ Security  │  │   Test    │  │Clarify    │   │
│  │   Gen     │  │ (Credo)   │  │(Sobelow)  │  │   Gen     │  │Question    │   │
│  └───────────┘  └───────────┘  └───────────┘  └───────────┘  └───────────┘   │
│                                                                              │
│  ┌───────────┐                                                              │
│  │Explanation│                                                              │
│  │   Gen     │                                                              │
│  └───────────┘                                                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                           Training Infrastructure                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │   Data      │    │ Curriculum  │    │   Multi-    │    │ Reinforce-  │      │
│  │  Pipeline   │    │  Learning   │    │   Task      │    │   ment      │      │
│  │             │    │  Scheduler  │    │  Loss       │    │  (Muzak)    │      │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                         Quad Knowledge Graph (TripleStore)                      │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │  Quads: (Subject, Predicate, Object, NamedGraph)                       │    │
│  │                                                                     │    │
│  │  Named Graphs:                                                     │    │
│  │  • graph:hex/{package}-{version}    → 13,597 Hex.pm package versions │    │
│  │  • graph:github/{repo}              → GitHub repository individuals    │    │
│  │  • graph:ontology/{schema}          → Core ontology schemas            │    │
│  │  • graph:train/val/test/{package}  → Training split graphs            │    │
│  │                                                                     │    │
│  │  SPARQL queries for context retrieval and ontology lookup           │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                            Data Sources                                        │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │   Hex.pm    │    │   GitHub    │    │  Elixir     │    │  Credo/     │      │
│  │  Packages   │    │  Repos      │    │ Ontologies  │    │  Sobelow    │      │
│  │  (13,597)   │    │             │    │  (.ttl)     │    │             │      │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘      │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
elixir-coder/
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── prod.exs
│   └── runtime.exs
├── lib/
│   └── elixir_coder/
│       ├── application.ex
│       ├── knowledge_graph/    # TripleStore integration
│       ├── tokenizer/
│       ├── data/
│       ├── model/
│       ├── training/
│       ├── inference/
│       ├── quality/
│       ├── security/
│       ├── testing/
│       └── evaluation/
├── data/
│   ├── raw/
│   ├── processed/
│   ├── knowledge_graph/     # TripleStore quad database
│   ├── ontologies/
│   ├── tokenizer/
│   └── checkpoints/
├── notes/
│   └── planning/
│       ├── overview.md
│       ├── phase-01-data-preparation.md
│       ├── phase-02-tokenizer.md
│       ├── phase-03-model-architecture.md
│       ├── phase-04-training-infrastructure.md
│       ├── phase-05-multi-task-training.md
│       ├── phase-06-inference-pipeline.md
│       └── phase-07-evaluation-production.md
└── test/
    └── elixir_coder/
```

## Phase Documents

- [Phase 1: Data Collection & Preparation](phase-01-data-preparation.md)
- [Phase 2: Tokenizer & Vocabulary](phase-02-tokenizer.md)
- [Phase 3: Model Architecture](phase-03-model-architecture.md)
- [Phase 4: Training Infrastructure](phase-04-training-infrastructure.md)
- [Phase 5: Multi-Task Training](phase-05-multi-task-training.md)
- [Phase 6: Inference Pipeline](phase-06-inference-pipeline.md)
- [Phase 7: Evaluation & Production](phase-07-evaluation-production.md)

## Success Criteria

| Phase | Success Criteria |
|-------|------------------|
| 1 | 13,597 packages in quad graph, 10K+ code-test pairs, 60%+ ontology coverage |
| 2 | 32K vocab, 100% Elixir symbol coverage, <5% unknown tokens |
| 3 | 125M-350M params, functional forward pass |
| 4 | >1000 samples/sec throughput, SPARQL queries <100ms |
| 5 | pass@1 > 70%, quality F1 > 0.6, security F1 > 0.5 |
| 6 | <5s p95 latency, 96% syntax error reduction |
| 7 | >98% uptime, <1% accuracy loss from optimization |

## Research Foundation

This implementation builds on research from:

- **GraphCodeBERT** - Data flow graph integration
- **K-BERT** - Knowledge triple injection
- **CodeT5/CodeT5+** - Encoder-decoder architecture
- **ClarifyGPT** - Ambiguity detection via divergence
- **Monitor-Guided Decoding** - Static analysis in decoding loop
- **SynCode** - Grammar-constrained generation
- **VulLLM** - Multi-task vulnerability detection
- **CodeRL** - Execution feedback for training
- **SpecFix** - Multi-sample requirement clarification
- **OTP Supervision Policy Task** - Context-aware failure behavior for supervised internals vs boundaries, planned across Phases 1/3/4/5/6/7 ([Research 1.07](../research/1.07-otp-supervision-policy/1.07.1-otp-supervision-policy-training.md))
- **Prompt Understanding Data Stream** - Mixed NL+code data, provenance/filters, and instruction-tuning/evaluation workflow ([Research 1.08](../research/1.08-natural-language-processing/1.08.1-nlp-training.md))
- **Edifice API Adoption Stream** - Use Edifice 0.2.0 capabilities by default across architecture/training/inference/optimization with explicit fallback paths
