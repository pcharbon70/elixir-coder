# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This project aims to build an ontology-augmented code generation model for Elixir. The goal is to combine RDF/OWL semantic annotations with Elixir source code to improve code generation through structured knowledge injection.

**Current Status**: Research/planning phase. No implementation code exists yet.

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

Ontology files (available at https://github.com/pcharbon70/elixir-ontologies):
- `elixir-core.ttl` - Core Elixir language semantics
- `elixir-otp.ttl` - OTP behaviours and patterns
- `elixir-structure.ttl` - Module and function structure
- `elixir-shapes.ttl` - SHACL shapes for validation (Credo rules and security constraints to be added)

Linearized triple format example:
```
[CODE] def handle_call(request, from, state) [/CODE]
[ONTO] <module>GenServer</module> <pattern>handle_call</pattern> <type>sync_request</type> [/ONTO]
```

## Build Commands

Once implementation begins, standard Elixir/Mix commands will apply:
```bash
mix deps.get          # Install dependencies
mix compile           # Compile the project
mix test              # Run tests
mix test path/to/test.exs:42  # Run single test at line
```

## Key Technical Decisions

- Use linearized triples over graph neural networks for initial implementation (simpler architecture)
- Hybrid approach: Python for graph preprocessing/embedding generation, Elixir for training/inference
- Curriculum learning: gradually introduce ontological complexity during training
- Parameter-efficient fine-tuning (LoRA) to work with limited Elixir corpus (~10k annotated functions minimum)
- Multi-task learning: jointly optimize code generation, Credo compliance, and security detection
- Constrained decoding: grammar constraints and monitor-guided decoding for quality/security enforcement
- Contrastive training: clean/violating code pairs from Credo and Sobelow for representation learning

## Training Objectives

The model uses a shared encoder-decoder transformer (CodeT5-style, 125M-350M parameters) with task-specific heads for six complementary objectives:
1. **Code generation** - Masked language modeling on Elixir code
2. **Quality compliance** - Credo rule violation classification (83+ checks across 5 categories)
3. **Security detection** - Sobelow finding classification (30+ vulnerability types mapped to CWE)
4. **Test generation** - Code-to-test and test-to-code bidirectional training with Muzak mutation feedback
5. **Clarification** - Ask-or-proceed decision + question generation for ambiguous requirements
6. **Explanation generation** - Natural language explanations grounded in rule documentation

## Curriculum Learning

Training progresses through phases, gradually introducing ontological complexity:

| Phase | Focus |
|-------|-------|
| 1 (epochs 1-10) | Code-only MLM |
| 2 (epochs 11-30) | Code + simple ontology annotations |
| 3 (epochs 31-50) | Code + full multi-hop ontology graphs |
| 4 (epochs 51+) | Complex examples + clarification training |

## Inference Pipeline

The clarification-first flow detects ambiguity via multi-sample divergence, then either asks a targeted question or proceeds with constrained decoding. Constrained decoding uses three layers:

| Layer | Approach | Overhead |
|-------|----------|----------|
| Syntax | Grammar-constrained via DFA mask stores | ~10% |
| Semantic | Monitor-guided decoding at trigger points | Variable |
| Quality/Security | Beam search with rejection sampling | 5x candidates |

A generate-check-repair loop validates output against Credo/Sobelow and refines if violations are found.

## Hybrid Architecture

- **Python**: Graph preprocessing, embedding generation (pyRDF2Vec, OWL2Vec*)
- **Elixir**: Training loop, inference, deployment via Nx.Serving

## Model Sizing

| Configuration | Parameters | Memory | Use Case |
|---------------|------------|--------|----------|
| Base model | 125M | ~1-2 GB | Development, fast iteration |
| Full model | 350M | ~4-6 GB | Production deployment |
| LoRA adapters | 2-4M each | ~4-10 MB | Test type specialization |

## Research Documentation

Detailed implementation guidance is available in `notes/research/`:
- `1.01` - Core ontology-augmented code generation architecture
- `1.02` - Credo integration for code quality (contrastive learning, constrained decoding)
- `1.03` - Sobelow integration for security (CWE mappings, OWASP patterns)
- `1.04` - Interactive clarification system (ambiguity detection, EVPI ranking)
- `1.05` - Test generation with Muzak mutation feedback
