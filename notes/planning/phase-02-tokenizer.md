# Phase 2: Tokenizer & Vocabulary

## Overview

Phase 2 creates the tokenization infrastructure for the Elixir LLM. By the end of this phase, we will have a custom Byte-Pair Encoding (BPE) tokenizer with a 32K vocabulary optimized for Elixir code, preserving key language constructs as atomic tokens.

The design recognizes that generic tokenizers fragment Elixir-specific constructs like `|>`, `:ok`, and `@spec` into multiple subwords, wasting context window and losing semantic coherence. Our custom tokenizer ensures these symbols remain single tokens, improving the model's understanding of Elixir idioms and reducing the effective sequence length for typical code.

This phase integrates with the Hugging Face tokenizers library via Rust NIFs for efficient training and inference, while storing vocabulary and merge rules in formats compatible with the broader ecosystem.

---

## 2.1 Tokenizer Architecture

- [ ] **Section 2.1 Complete**

This section establishes the tokenizer architecture, selecting the BPE algorithm and defining the vocabulary size target based on corpus analysis.

We choose BPE over WordPiece or Unigram for its simplicity and proven effectiveness on code. The 32K vocabulary size balances coverage against embedding matrix size, fitting well within the 125M-350M parameter target for the full model.

### 2.1.1 Algorithm Selection

- [ ] **Task 2.1.1 Complete**

Select and justify BPE as the tokenization algorithm.

- [ ] 2.1.1.1 Research BPE vs. WordPiece vs. Unigram for code
- [ ] 2.1.1.2 Document decision: BPE for simplicity, proven results (GPT-2, GPT-3)
- [ ] 2.1.1.3 Create `notes/tokenization/algorithm-selection.md` with analysis
- [ ] 2.1.1.4 Benchmark BPE on sample Elixir code

### 2.1.2 Vocabulary Sizing

- [ ] **Task 2.1.2 Complete**

Determine optimal vocabulary size based on corpus analysis.

- [ ] 2.1.2.1 Implement `ElixirCoder.Tokenizer.Analyze.corpus_statistics/1`
- [ ] 2.1.2.2 Compute unique tokens, frequency distribution, coverage curves
- [ ] 2.1.2.3 Plot coverage vs. vocabulary size for 8K, 16K, 32K, 50K
- [ ] 2.1.2.4 Select 32K as target (covers >95% of tokens with <15% fragmentation)
- [ ] 2.1.2.5 Document sizing decision in `notes/tokenization/vocabulary-size.md`

### 2.1.3 Elixir Symbol Identification

- [ ] **Task 2.1.3 Complete**

Identify Elixir-specific symbols that must be preserved as single tokens.

- [ ] 2.1.3.1 Define operator list: `|>`, `<<<`, `>>>`, `->`, `<-`, `=>`, `|`, `::`, `++`, `--`, `<>`, `=~`
- [ ] 2.1.3.2 Define atom list: `:ok`, `:error`, `:nil`, `:true`, `:false`, `:undefined`
- [ ] 2.1.3.3 Define attribute list: `@spec`, `@type`, `@doc`, `@moduledoc`, `@behaviour`, `@impl`, `@callback`, `@macrocallback`
- [ ] 2.1.3.4 Define keyword list: `defmodule`, `def`, `defp`, `defmacro`, `defmacrop`, `defstruct`, `use`, `import`, `require`, `alias`
- [ ] 2.1.3.5 Define sigil list: `~r`, `~w`, `~s`, `~c`, `~R`, `~W`, `~S`, `~C`, `~a`, `~A`
- [ ] 2.1.3.6 Define control flow: `do`, `end`, `fn`, `when`, `case`, `cond`, `with`, `for`, `if`, `unless`, `else`, `rescue`, `catch`, `after`
- [ ] 2.1.3.7 Define test constructs: `describe`, `test`, `property`, `check`, `assert`, `refute`, `assert_raise`

### 2.1.4 Special Token Definitions

- [ ] **Task 2.1.4 Complete**

Define special tokens for model-specific purposes.

- [ ] 2.1.4.1 Define `"<|code|>"` token for code sections
- [ ] 2.1.4.2 Define `"<|ontology|>"` token for ontology annotations
- [ ] 2.1.4.3 Define `"<|test|>"` token for test code
- [ ] 2.1.4.4 Define `"<|explanation|>"` token for explanations
- [ ] 2.1.4.5 Define `"<|clarification|>"` token for questions
- [ ] 2.1.4.6 Define standard special tokens: `<pad>`, `<eos>`, `<bos>`, `<unk>`, `<mask>`

### 2.1.5 Unit Tests

- [ ] **Task 2.1.5 Complete**

- [ ] Test corpus statistics produces valid counts
- [ ] Test coverage curve shows diminishing returns after 32K
- [ ] Test Elixir symbols are comprehensive
- [ ] Test special tokens don't conflict with vocabulary

---

## 2.2 BPE Training Pipeline

- [ ] **Section 2.2 Complete**

This section implements the BPE training pipeline that learns merge rules from the Elixir corpus, creating the vocabulary optimized for Elixir code.

We use a hybrid approach: Python's tokenizers library for efficient BPE training, with Elixir wrappers for integration into the project. This leverages mature Rust-backed tokenization while maintaining Elixir-native workflows.

### 2.2.1 Corpus Preprocessing

- [ ] **Task 2.2.1 Complete**

Implement corpus preprocessing for BPE training.

- [ ] 2.2.1.1 Implement `ElixirCoder.Tokenizer.Trainer.prepare_corpus/1`
- [ ] 2.2.1.2 Read all files from `data/processed/train.jsonl`
- [ ] 2.2.1.3 Extract code content, filter to Elixir files only
- [ ] 2.2.1.4 Normalize whitespace while preserving indentation
- [ ] 2.2.1.5 Write to `data/tokenizer/corpus.txt` (one sample per line)

### 2.2.2 Python Training Script

- [ ] **Task 2.2.2 Complete**

Create Python script for BPE training with user-defined symbols.

- [ ] 2.2.2.1 Create `python/train_tokenizer.py`
- [ ] 2.2.2.2 Use `tokenizers.trainers.BpeTrainer` with special_tokens
- [ ] 2.2.2.3 Pass Elixir symbols as `user_defined_symbols`
- [ ] 2.2.2.4 Configure vocab_size=32000, min_frequency=2
- [ ] 2.2.2.5 Output vocabulary to `data/tokenizer/vocab.json`
- [ ] 2.2.2.6 Output merges to `data/tokenizer/merges.txt`

### 2.2.3 Elixir Training Wrapper

- [ ] **Task 2.2.3 Complete**

Implement Elixir wrapper for invoking Python training.

- [ ] 2.2.3.1 Implement `ElixirCoder.Tokenizer.Trainer.train_bpe/1`
- [ ] 2.2.3.2 Use `System.cmd` to invoke Python script
- [ ] 2.2.3.3 Pass corpus path, output paths, special tokens
- [ ] 2.2.3.4 Capture and parse training output
- [ ] 2.2.3.5 Return vocabulary size, merge count, training time

### 2.2.4 Incremental Training

- [ ] **Task 2.2.4 Complete**

Support incremental vocabulary expansion as corpus grows.

- [ ] 2.2.4.1 Implement `ElixirCoder.Tokenizer.Trainer.expand_vocab/2`
- [ ] 2.2.4.2 Load existing tokenizer and add new merges
- [ ] 2.2.4.3 Preserve existing token IDs for stability
- [ ] 2.2.4.4 Append new tokens to vocabulary

### 2.2.5 Unit Tests

- [ ] **Task 2.2.5 Complete**

- [ ] Test corpus preprocessing produces valid text
- [ ] Test Python script produces JSON and txt outputs
- [ ] Test Elixir wrapper invokes Python correctly
- [ ] Test incremental training preserves existing tokens

---

## 2.3 Tokenizer Implementation

- [ ] **Section 2.3 Complete**

This section implements the Elixir tokenizer using the trained vocabulary and merges, providing encode/decode operations for the training pipeline.

We use the `tokenizers` Elixir library (Rust NIF bindings to Hugging Face tokenizers) for efficient encoding at scale.

### 2.3.1 Tokenizer Loading

- [ ] **Task 2.3.1 Complete**

Implement loading of trained tokenizer from disk.

- [ ] 2.3.1.1 Implement `ElixirCoder.Tokenizer.load!/1`
- [ ] 2.3.1.2 Load `vocab.json` and `merges.txt` from path
- [ ] 2.3.1.3 Create `Tokenizer.Tokenizer` from files
- [ ] 2.3.1.4 Cache tokenizer in `:persistent_term` for performance

### 2.3.2 Encoding Operations

- [ ] **Task 2.3.2 Complete**

Implement text-to-token encoding.

- [ ] 2.3.2.1 Implement `ElixirCoder.Tokenizer.encode/2`
- [ ] 2.3.2.2 Return `Tokenizer.Encoding` struct with ids, tokens, offsets
- [ ] 2.3.2.3 Support truncation with `max_length` parameter
- [ ] 2.3.2.4 Support padding with `padding: :max_length` option
- [ ] 2.3.2.5 Return Nx tensor with shape `{batch, seq_len}`

### 2.3.3 Decoding Operations

- [ ] **Task 2.3.3 Complete**

Implement token-to-text decoding.

- [ ] 2.3.3.1 Implement `ElixirCoder.Tokenizer.decode/1`
- [ ] 2.3.3.2 Accept list of token IDs or Nx tensor
- [ ] 2.3.3.3 Skip special tokens (pad, eos, bos) by default
- [ ] 2.3.3.4 Handle byte-fallback for unknown tokens
- [ ] 2.3.3.5 Return reconstructed string

### 2.3.4 Batch Processing

- [ ] **Task 2.3.4 Complete**

Implement efficient batch encoding/decoding.

- [ ] 2.3.4.1 Implement `ElixirCoder.Tokenizer.encode_batch/2`
- [ ] 2.3.4.2 Accept list of strings, return padded batch tensor
- [ ] 2.3.4.3 Implement attention mask generation
- [ ] 2.3.4.4 Support dynamic batching (group by length)

### 2.3.5 Unit Tests

- [ ] **Task 2.3.5 Complete**

- [ ] Test tokenizer loads from disk correctly
- [ ] Test encoding roundtrip preserves text
- [ ] Test special tokens are preserved
- [ ] Test Elixir symbols are single tokens
- [ ] Test batch encoding produces consistent shapes
- [ ] Test attention mask is correct

---

## 2.4 Tokenizer Analysis

- [ ] **Section 2.4 Complete**

This section analyzes the trained tokenizer to validate it meets requirements and identify any issues.

### 2.4.1 Vocabulary Coverage

- [ ] **Task 2.4.1 Complete**

Analyze vocabulary coverage on held-out test set.

- [ ] 2.4.1.1 Implement `ElixirCoder.Tokenizer.Analyze.coverage/2`
- [ ] 2.4.1.2 Compute percentage of tokens that are unknown
- [ ] 2.4.1.3 Compute average tokens per word
- [ ] 2.4.1.4 Target: <5% unknown tokens, <1.15 tokens/word ratio

### 2.4.2 Elixir Symbol Verification

- [ ] **Task 2.4.2 Complete**

Verify all Elixir symbols are single tokens.

- [ ] 2.4.2.1 Implement `ElixirCoder.Tokenizer.Analyze.verify_symbols/1`
- [ ] 2.4.2.2 Check each symbol in list is single token
- [ ] 2.4.2.3 Report any symbols that are split
- [ ] 2.4.2.4 Target: 100% of symbols preserved

### 2.4.3 Sequence Length Analysis

- [ ] **Task 2.4.3 Complete**

Analyze sequence length distribution for training.

- [ ] 2.4.3.1 Implement `ElixirCoder.Tokenizer.Analyze.sequence_lengths/1`
- [ ] 2.4.3.2 Compute mean, median, p95, p99 lengths
- [ ] 2.4.3.3 Determine max sequence length (target 4096)
- [ ] 2.4.3.4 Report percentage of samples exceeding max length

### 2.4.4 Benchmarking

- [ ] **Task 2.4.4 Complete**

Benchmark tokenizer performance for sizing.

- [ ] 2.4.4.1 Implement `ElixirCoder.Tokenizer.Analyze.benchmark/1`
- [ ] 2.4.4.2 Measure encode/decode throughput (tokens/sec)
- [ ] 2.4.4.3 Measure memory usage during batching
- [ ] 2.4.4.4 Target: >50K tokens/sec encode, >100K tokens/sec decode

### 2.4.5 Unit Tests

- [ ] **Task 2.4.5 Complete**

- [ ] Test coverage exceeds threshold
- [ ] Test Elixir symbols are verified
- [ ] Test sequence lengths computed correctly
- [ ] Test benchmark produces valid metrics

---

## 2.5 Tokenizer Integration

- [ ] **Section 2.5 Complete**

This section integrates the tokenizer with the data pipeline for training dataset preparation.

### 2.5.1 Dataset Tokenization

- [ ] **Task 2.5.1 Complete**

Implement tokenization of training dataset.

- [ ] 2.5.1.1 Implement `ElixirCoder.Tokenizer.Dataset.tokenize_pairs/2`
- [ ] 2.5.1.2 Read `data/processed/train.jsonl`
- [ ] 2.5.1.3 Tokenize code and test fields separately
- [ ] 2.5.1.4 Include ontology annotations as special tokens
- [ ] 2.5.1.5 Write `data/tokenized/train.bin` (Nx serialized)

### 2.5.2 Efficient Storage Format

- [ ] **Task 2.5.2 Complete**

Implement efficient binary storage for tokenized data.

- [ ] 2.5.2.1 Define binary format: header, samples (count, ids, masks)
- [ ] 2.5.2.2 Use Nx serializer for tensor data
- [ ] 2.5.2.3 Compress with gzip to reduce disk usage
- [ ] 2.5.2.4 Implement random access for training shuffling

### 2.5.3 Data Loading Pipeline

- [ ] **Task 2.5.3 Complete**

Implement streaming data loader for training.

- [ ] 2.5.3.1 Implement `ElixirCoder.Tokenizer.Dataset.stream/2`
- [ ] 2.5.3.2 Stream from tokenized binary without full load
- [ ] 2.5.3.3 Support batching with random shuffling
- [ ] 2.5.3.4 Prefetch batches for GPU throughput

### 2.5.4 Unit Tests

- [ ] **Task 2.5.4 Complete**

- [ ] Test dataset tokenization produces valid tensors
- [ ] Test binary format roundtrips correctly
- [ ] Test streaming loader yields consistent batches
- [ ] Test random access returns correct samples

---

## Success Criteria

1. **Vocabulary Size**: 32K tokens with full Elixir symbol coverage
2. **Symbol Preservation**: 100% of Elixir symbols are single tokens
3. **Coverage**: <5% unknown tokens on test set
4. **Performance**: >50K tokens/sec encoding throughput
5. **Sequence Length**: 95% of samples < 4096 tokens

## Provides Foundation

This phase establishes the tokenization for:
- **Phase 3**: Vocabulary size determines embedding layer dimensions
- **Phase 4**: Tokenized data feeds training pipeline
- **Phase 6**: Tokenizer used at inference time
