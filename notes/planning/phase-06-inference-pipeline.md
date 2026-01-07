# Phase 6: Inference Pipeline

## Overview

Phase 6 implements the inference pipeline that deploys the trained model for production use. By the end of this phase, we will have a complete serving system with clarification detection, constrained decoding, generate-check-repair loops, and explanation generation.

The design prioritizes correctness and user experience. The system detects ambiguous requirements and asks clarifying questions before generating code. During generation, it applies constraints to ensure syntactic validity and quality compliance. After generation, it verifies output with Credo and Sobelow, repairing issues if found.

This phase transforms the trained model into a production-ready code generation service.

---

## 6.1 Model Serving

- [ ] **Section 6.1 Complete**

This section implements model serving using Nx.Serving for efficient batched inference.

### 6.1.1 Serving Initialization

- [ ] **Task 6.1.1 Complete**

Initialize Nx.Serving with trained model.

- [ ] 6.1.1.1 Implement `ElixirCoder.Inference.Serving.new/2`
- [ ] 6.1.1.2 Load trained model from checkpoint
- [ ] 6.1.1.3 Load tokenizer
- [ ] 6.1.1.4 Configure batch size and sequence length
- [ ] 6.1.1.5 Set compiler: EXLA for GPU

### 6.1.2 Batch Processing

- [ ] **Task 6.1.2 Complete**

Implement efficient batch processing.

- [ ] 6.1.2.1 Configure dynamic batching
- [ ] 6.1.2.2 Set batch timeout (max wait for full batch)
- [ ] 6.1.2.3 Handle variable sequence lengths
- [ ] 6.1.2.4 Return results in request order

### 6.1.3 Serving Process

- [ ] **Task 6.1.3 Complete**

Implement GenServer-based serving process.

- [ ] 6.1.3.1 Implement `ElixirCoder.Inference.Server` GenServer
- [ ] 6.1.3.2 Start Nx.Serving on init
- [ ] 6.1.3.3 Handle synchronous requests
- [ ] 6.1.3.4 Handle streaming responses
- [ ] 6.1.3.5 Add supervision tree

### 6.1.4 Multiple Model Instances

- [ ] **Task 6.1.4 Complete**

Support multiple model instances (A/B testing).

- [ ] 6.1.4.1 Implement named model instances
- [ ] 6.1.4.2 Route requests to specific instances
- [ ] 6.1.4.3 Support concurrent instances
- [ ] 6.1.4.4 Add load balancing

### 6.1.5 Unit Tests

- [ ] **Task 6.1.5 Complete**

- [ ] Test serving initializes with model
- [ ] Test batch processing produces consistent outputs
- [ ] Test server handles concurrent requests
- [ ] Test multiple instances run independently

---

## 6.2 Clarification Detection

- [ ] **Section 6.2 Complete**

This section implements ambiguity detection that determines when to ask clarifying questions before code generation.

### 6.2.1 Multi-Sample Generation

- [ ] **Task 6.2.1 Complete**

Implement multi-sample generation for divergence detection.

- [ ] 6.2.1.1 Implement `ElixirCoder.Inference.Clarification.generate_samples/3`
- [ ] 6.2.1.2 Generate N samples with temperature 0.8
- [ ] 6.2.1.3 Use different random seeds
- [ ] 6.2.1.4 Collect all generated samples

### 6.2.2 Divergence Computation

- [ ] **Task 6.2.2 Complete**

Compute semantic divergence between samples.

- [ ] 6.2.2.1 Implement `ElixirCoder.Inference.Clarification.compute_divergence/1`
- [ ] 6.2.2.2 Parse AST of each sample
- [ ] 6.2.2.3 Compare structure (function definitions, imports)
- [ ] 6.2.2.4 Compare behavior (patterns used, error handling)
- [ ] 6.2.2.5 Cluster samples by similarity

### 6.2.3 Semantic Entropy

- [ ] **Task 6.2.3 Complete**

Compute semantic entropy for uncertainty quantification.

- [ ] 6.2.3.1 Implement `ElixirCoder.Inference.Clarification.semantic_entropy/1`
- [ ] 6.2.3.2 Compute cluster probabilities
- [ ] 6.2.3.3 Calculate entropy: -Σ p_i * log(p_i)
- [ ] 6.2.3.4 Return entropy score

### 6.2.4 Ask-or-Proceed Decision

- [ ] **Task 6.2.4 Complete**

Implement decision logic for asking questions.

- [ ] 6.2.4.1 Implement `ElixirCoder.Inference.Clarification.should_ask?/2`
- [ ] 6.2.4.2 Check entropy threshold (default 0.5)
- [ ] 6.2.4.3 Check cluster count threshold (default 3)
- [ ] 6.2.4.4 Return {:ask, ambiguity} or {:proceed, confidence}

### 6.2.5 Unit Tests

- [ ] **Task 6.2.5 Complete**

- [ ] Test multi-sample generation produces variety
- [ ] Test divergence computation detects differences
- [ ] Test semantic entropy increases with clusters
- [ ] Test ask/proceed decision respects thresholds

---

## 6.3 Question Generation

- [ ] **Section 6.3 Complete**

This section implements clarifying question generation when ambiguity is detected.

### 6.3.1 Ambiguity Type Classification

- [ ] **Task 6.3.1 Complete**

Classify the type of ambiguity detected.

- [ ] 6.3.1.1 Implement `ElixirCoder.Inference.Questions.classify_ambiguity/1`
- [ ] 6.3.1.2 Types: :error_handling, :concurrency, :data_structure, :external_dependency
- [ ] 6.3.1.3 Analyze divergent samples for patterns
- [ ] 6.3.1.4 Return ambiguity type

### 6.3.2 EVPI Ranking

- [ ] **Task 6.3.2 Complete**

Rank questions by Expected Value of Perfect Information.

- [ ] 6.3.2.1 Implement `ElixirCoder.Inference.Questions.rank_evpi/3`
- [ ] 6.3.2.2 Estimate information gain for each question
- [ ] 6.3.2.3 Estimate utility improvement from answer
- [ ] 6.3.2.4 Return ranked question list

### 6.3.3 Template-Based Generation

- [ ] **Task 6.3.3 Complete**

Generate questions using templates.

- [ ] 6.3.3.1 Create question templates for each ambiguity type
- [ ] 6.3.3.2 Fill templates with context from prompt
- [ ] 6.3.3.3 Provide multiple choice options when applicable
- [ ] 6.3.3.4 Return formatted question

### 6.3.4 Model-Based Generation

- [ ] **Task 6.3.4 Complete**

Generate questions using the question head.

- [ ] 6.3.4.1 Use question generation head
- [ ] 6.3.4.2 Condition on ambiguity type
- [ ] 6.3.4.3 Generate natural language question
- [ ] 6.3.4.4 Ensure question is specific and answerable

### 6.3.5 Unit Tests

- [ ] **Task 6.3.5 Complete**

- [ ] Test ambiguity classification produces valid type
- [ ] Test EVPI ranking prioritizes high-value questions
- [ ] Test template generation produces valid questions
- [ ] Test model generation produces relevant questions

---

## 6.4 Constrained Decoding

- [ ] **Section 6.4 Complete**

This section implements constrained decoding that ensures generated code is syntactically valid and respects quality/security constraints.

### 6.4.1 Grammar Constraints

- [ ] **Task 6.4.1 Complete**

Implement grammar-constrained decoding for Elixir.

- [ ] 6.4.1.1 Define Elixir grammar in EBNF
- [ ] 6.4.1.2 Compile grammar to DFA
- [ ] 6.4.1.3 Create mask store for valid tokens per state
- [ ] 6.4.1.4 Implement mask application at each step

### 6.4.2 Mask Store Construction

- [ ] **Task 6.4.2 Complete**

Build mask store for efficient constraint application.

- [ ] 6.4.2.1 Implement `ElixirCoder.Inference.Constraints.build_mask_store/1`
- [ ] 6.4.2.2 Precompute valid tokens for each grammar state
- [ ] 6.4.2.3 Store in efficient lookup structure
- [ ] 6.4.2.4 Support incremental updates

### 6.4.3 Monitor-Guided Decoding

- [ ] **Task 6.4.3 Complete**

Integrate static analysis into decoding loop.

- [ ] 6.4.3.1 Implement `ElixirCoder.Inference.Constraints.monitor_guided/3`
- [ ] 6.4.3.2 Trigger analysis at semantic boundaries
- [ ] 6.4.3.3 Query Credo for valid continuations
- [ ] 6.4.3.4 Mask tokens that would violate rules

### 6.4.4 Constraint Application

- [ ] **Task 6.4.4 Complete**

Apply constraints during generation.

- [ ] 6.4.4.1 Implement `ElixirCoder.Inference.Constraints.apply_mask/3`
- [ ] 6.4.4.2 Get logits from model
- [ ] 6.4.4.3 Compute constraint mask
- [ ] 6.4.4.4 Apply mask: set invalid tokens to -inf
- [ ] 6.4.4.5 Sample from masked distribution

### 6.4.5 Unit Tests

- [ ] **Task 6.4.5 Complete**

- [ ] Test grammar DFA validates Elixir syntax
- [ ] Test mask store returns correct valid tokens
- [ ] Test monitor-guided detects violations
- [ ] Test constrained generation produces valid code

---

## 6.5 Generate-Check-Repair Loop

- [ ] **Section 6.5 Complete**

This section implements the generate-check-repair loop that validates generated code and repairs issues if found.

### 6.5.1 Code Generation

- [ ] **Task 6.5.1 Complete**

Implement initial code generation.

- [ ] 6.5.1.1 Implement `ElixirCoder.Inference.Generation.generate/3`
- [ ] 6.5.1.2 Accept prompt and any clarification answers
- [ ] 6.5.1.3 Apply constrained decoding
- [ ] 6.5.1.4 Generate N candidates (default 5)
- [ ] 6.5.1.5 Return candidates ranked by log-prob

### 6.5.2 Quality Checking

- [ ] **Task 6.5.2 Complete**

Implement quality checking with Credo.

- [ ] 6.5.2.1 Implement `ElixirCoder.Inference.Check.check_quality/1`
- [ ] 6.5.2.2 Run Credo on generated code
- [ ] 6.5.2.3 Parse issues from JSON output
- [ ] 6.5.2.4 Return {:ok, code} or {:error, issues}

### 6.5.3 Security Checking

- [ ] **Task 6.5.3 Complete**

Implement security checking with Sobelow.

- [ ] 6.5.3.1 Implement `ElixirCoder.Inference.Check.check_security/1`
- [ ] 6.5.3.2 Run Sobelow on generated code
- [ ] 6.5.3.3 Parse findings from JSON output
- [ ] 6.5.3.4 Return {:ok, code} or {:error, findings}

### 6.5.4 Syntax Checking

- [ ] **Task 6.5.4 Complete**

Implement syntax validation.

- [ ] 6.5.4.1 Implement `ElixirCoder.Inference.Check.check_syntax/1`
- [ ] 6.5.4.2 Use `Code.string_to_quoted/1`
- [ ] 6.5.4.3 Return {:ok, ast} or {:error, reason}
- [ ] 6.5.4.4 Provide error location

### 6.5.5 Repair Prompt Generation

- [ ] **Task 6.5.5 Complete**

Generate repair prompts for failed candidates.

- [ ] 6.5.5.1 Implement `ElixirCoder.Inference.Repair.build_prompt/3`
- [ ] 6.5.5.2 Include original prompt
- [ ] 6.5.5.3 Include failed code
- [ ] 6.5.5.4 Include error/issue details
- [ ] 6.5.5.5 Ask model to fix specific issues

### 6.5.6 Loop Implementation

- [ ] **Task 6.5.6 Complete**

Implement full generate-check-repair loop.

- [ ] 6.5.6.1 Implement `ElixirCoder.Inference.Loop.generate_with_repair/3`
- [ ] 6.5.6.2 Generate candidates
- [ ] 6.5.6.3 Check each candidate (syntax, quality, security)
- [ ] 6.5.6.4 Return first clean candidate
- [ ] 6.5.6.5 If none clean, repair best candidate and retry
- [ ] 6.5.6.6 Max attempts: 3

### 6.5.7 Unit Tests

- [ ] **Task 6.5.7 Complete**

- [ ] Test generation produces candidates
- [ ] Test quality checking detects Credo issues
- [ ] Test security checking detects Sobelow findings
- [ ] Test syntax checking validates code
- [ ] Test repair prompt includes errors
- [ ] Test loop terminates with clean code or error

---

## 6.6 Explanation Generation

- [ ] **Section 6.6 Complete**

This section implements explanation generation for code quality and security issues.

### 6.6.1 Issue Context Extraction

- [ ] **Task 6.6.1 Complete**

Extract context for explanation.

- [ ] 6.6.1.1 Implement `ElixirCoder.Inference.Explanation.extract_context/2`
- [ ] 6.6.1.2 Extract relevant code snippet
- [ ] 6.6.1.3 Extract issue details (check, message, location)
- [ ] 6.6.1.4 Include ontology information

### 6.6.2 RAG Context Retrieval

- [ ] **Task 6.6.2 Complete**

Retrieve relevant documentation for explanation.

- [ ] 6.6.2.1 Implement `ElixirCoder.Inference.Explanation.retrieve_docs/2`
- [ ] 6.6.2.2 Search indexed Credo/Sobelow documentation
- [ ] 6.6.2.3 Retrieve relevant CWE descriptions
- [ ] 6.6.2.4 Return context snippets

### 6.6.3 Explanation Generation

- [ ] **Task 6.6.3 Complete**

Generate natural language explanations.

- [ ] 6.6.3.1 Use explanation head
- [ ] 6.6.3.2 Condition on issue type
- [ ] 6.6.3.3 Include RAG context
- [ ] 6.6.3.4 Generate chain-of-thought explanation
- [ ] 6.6.3.5 Include fix suggestions

### 6.6.4 Explanation Formatting

- [ ] **Task 6.6.4 Complete**

Format explanations for display.

- [ ] 6.6.4.1 Structure explanation with sections
- [ ] 6.6.4.2 Include: what, why, how to fix
- [ ] 6.6.4.3 Add code examples for fixes
- [ ] 6.6.4.4 Format as markdown

### 6.6.5 Unit Tests

- [ ] **Task 6.6.5 Complete**

- [ ] Test context extraction includes relevant info
- [ ] Test RAG retrieval returns docs
- [ ] Test explanation generation produces text
- [ ] Test formatting produces valid markdown

---

## 6.7 API Interface

- [ ] **Section 6.7 Complete**

This section implements the public API for the inference service.

### 6.7.1 Generation API

- [ ] **Task 6.7.1 Complete**

Implement main code generation API.

- [ ] 6.7.1.1 Implement `ElixirCoder.generate/2`
- [ ] 6.7.1.2 Accept prompt and options
- [ ] 6.7.1.3 Return: {:ok, code} or {:clarification_needed, question}
- [ ] 6.7.1.4 Support: `generate/2` and `generate_with_clarification/3`

### 6.7.2 Clarification API

- [ ] **Task 6.7.2 Complete**

Implement clarification interaction API.

- [ ] 6.7.2.1 Implement `ElixirCoder.ask_clarification/2`
- [ ] 6.7.2.2 Return question for user
- [ ] 6.7.2.3 Implement `ElixirCoder.answer_clarification/3`
- [ ] 6.7.2.4 Accept answer and generate code with context

### 6.7.3 Explanation API

- [ ] **Task 6.7.3 Complete**

Implement explanation generation API.

- [ ] 6.7.3.1 Implement `ElixirCoder.explain/2`
- [ ] 6.7.3.2 Accept code and issue
- [ ] 6.7.3.3 Return explanation text
- [ ] 6.7.3.4 Include fix suggestions

### 6.7.4 Batch API

- [ ] **Task 6.7.4 Complete**

Implement batch processing API.

- [ ] 6.7.4.1 Implement `ElixirCoder.generate_batch/2`
- [ ] 6.7.4.2 Accept list of prompts
- [ ] 6.7.4.3 Return list of results
- [ ] 6.7.4.4 Process in parallel

### 6.7.5 Unit Tests

- [ ] **Task 6.7.5 Complete**

- [ ] Test generate returns code or clarification
- [ ] Test clarification interaction works end-to-end
- [ ] Test explain returns valid explanation
- [ ] Test batch processes all prompts

---

## Success Criteria

1. **Serving**: Handles 10+ concurrent requests
2. **Clarification**: Detects ambiguity with >70% precision
3. **Constraints**: 96% reduction in syntax errors
4. **Repair Loop**: Produces clean code in <3 iterations
5. **API**: Response time <5 seconds for typical prompts

## Provides Foundation

This phase produces the inference system for:
- **Phase 7**: Production deployment and evaluation
