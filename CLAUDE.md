# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This project aims to build an ontology-augmented code generation model for Elixir. The goal is to combine RDF/OWL semantic annotations with Elixir source code to improve code generation through structured knowledge injection.

**Current Status**: Research/planning phase. No implementation code exists yet.

## Planned Architecture

The system will use:
- **Linearized triple representations** for combining RDF/OWL ontologies with code tokens
- **Axon** for neural network layers (with custom graph attention implementations)
- **Bumblebee** for tokenization
- **EXLA** for GPU acceleration
- **rdf-ex** for RDF parsing
- **Credo** for code quality analysis and training data labeling
- **Sobelow** for security vulnerability detection and constrained decoding

Ontology files (available at https://github.com/pcharbon70/elixir-ontologies):
- `elixir-core.ttl` - Core Elixir language semantics
- `elixir-otp.ttl` - OTP behaviours and patterns
- `elixir-structure.ttl` - Module and function structure
- `elixir-shapes.ttl` - SHACL shapes for validation (Credo rules and security constraints to be added)

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

The model targets multiple complementary objectives:
1. **Code generation** - Masked language modeling on Elixir code
2. **Quality compliance** - Credo rule violation classification (83+ checks across 5 categories)
3. **Security detection** - Sobelow finding classification (30+ vulnerability types mapped to CWE)
4. **Explanation generation** - Natural language explanations grounded in rule documentation
