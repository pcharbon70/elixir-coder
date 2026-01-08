# Phase 5: Multi-Task Training

## Overview

Phase 5 executes the actual training of the multi-task model, running through the curriculum learning schedule and validating performance across all tasks. By the end of this phase, we will have a fully trained model capable of code generation, quality assessment, security detection, test generation, clarification, and explanation.

The design emphasizes monitoring and iteration. We track metrics for each task independently, validating on held-out sets after each epoch. The curriculum learning approach gradually introduces complexity, preventing the model from being overwhelmed by all tasks simultaneously.

This phase is the culmination of all previous work, combining data, tokenization, model architecture, and training infrastructure into a complete training run.

---

## 5.1 Training Execution

- [ ] **Section 5.1 Complete**

This section executes the full training run through all curriculum phases, monitoring progress and making adjustments as needed.

### 5.1.1 Pre-Training Checks

- [ ] **Task 5.1.1 Complete**

Run pre-training validation checks.

- [ ] 5.1.1.1 Verify dataset完整性 (all splits present)
- [ ] 5.1.1.2 Verify tokenizer loads correctly
- [ ] 5.1.1.3 Verify model builds without errors
- [ ] 5.1.1.4 Verify GPU available (EXLA)
- [ ] 5.1.1.5 Run forward pass with dummy input
- [ ] 5.1.1.6 Compute parameter count

### 5.1.2 Initial Training Run

- [ ] **Task 5.1.2 Complete**

Execute initial training on Phase 1 (code-only).

- [ ] 5.1.2.1 Run 10 epochs on code generation only
- [ ] 5.1.2.2 Monitor training loss decrease
- [ ] 5.1.2.3 Monitor validation loss for overfitting
- [ ] 5.1.2.4 Target: validation loss < 3.5
- [ ] 5.1.2.5 Save checkpoint after epoch 10

### 5.1.3 Ontology Augmentation Training

- [ ] **Task 5.1.3 Complete**

Execute Phase 2 training with ontology annotations.

- [ ] 5.1.3.1 Run epochs 11-30 with simple ontology
- [ ] 5.1.3.2 Gradually introduce ontology complexity
- [ ] 5.1.3.3 Monitor ontology-related metrics
- [ ] 5.1.3.4 Target: ontology utilization > 80%
- [ ] 5.1.3.5 Save checkpoints every 5 epochs

### 5.1.4 Full Ontology Training

- [ ] **Task 5.1.4 Complete**

Execute Phase 3 training with full ontology graphs.

- [ ] 5.1.4.1 Run epochs 31-50 with multi-hop ontology
- [ ] 5.1.4.2 Include complex relationship patterns
- [ ] 5.1.4.3 Monitor semantic understanding metrics
- [ ] 5.1.4.4 Target: pass@1 improvement > 5% vs Phase 1

### 5.1.5 Multi-Task Training

- [ ] **Task 5.1.5 Complete**

Execute Phase 4 training with all tasks active.

- [ ] 5.1.5.1 Run epochs 51+ with all task heads
- [ ] 5.1.5.2 Balance multi-task loss weights
- [ ] 5.1.5.3 Monitor per-task validation metrics
- [ ] 5.1.5.4 Adjust weights if any task degrades
- [ ] 5.1.5.5 Target: all tasks show improvement

### 5.1.6 Training Completion

- [ ] **Task 5.1.6 Complete**

Finalize training when convergence criteria met.

- [ ] 5.1.6.1 Check validation loss plateau (no improvement for 5 epochs)
- [ ] 5.1.6.2 Select best checkpoint by validation loss
- [ ] 5.1.6.3 Export final model to `data/models/final/`
- [ ] 5.1.6.4 Generate training report

---

## 5.2 Code Generation Training

- [ ] **Section 5.2 Complete**

This section focuses on training and evaluating the code generation task, the primary objective of the model.

### 5.2.1 Masked Language Modeling

- [ ] **Task 5.2.1 Complete**

Train with masked span prediction objective.

- [ ] 5.2.1.1 Implement random span masking (15% of tokens)
- [ ] 5.2.1.2 Mask spans of 1-5 consecutive tokens
- [ ] 5.2.1.3 Replace with `<mask>` token
- [ ] 5.2.1.4 Train model to predict original tokens
- [ ] 5.2.1.5 Monitor masking accuracy

### 5.2.2 Fill-in-the-Middle

- [ ] **Task 5.2.2 Complete**

Train with FIM objective for completion.

- [ ] 5.2.2.1 Split code into prefix/middle/suffix
- [ ] 5.2.2.2 Train to generate middle given prefix+suffix
- [ ] 5.2.2.3 Use special FIM tokens
- [ ] 5.2.2.4 Mix 50% MLM, 50% FIM in training

### 5.2.3 Causal Language Modeling

- [ ] **Task 5.2.3 Complete**

Train causal LM for generation.

- [ ] 5.2.3.1 Train decoder-only style generation
- [ ] 5.2.3.2 Use causal masking
- [ ] 5.2.3.3 Support for autoregressive sampling
- [ ] 5.2.3.4 Monitor perplexity

### 5.2.4 Code Generation Evaluation

- [ ] **Task 5.2.4 Complete**

Evaluate code generation quality.

- [ ] 5.2.4.1 Compute pass@1 on validation set
- [ ] 5.2.4.2 Compute pass@10 for ceiling
- [ ] 5.2.4.3 Compute CodeBLEU for similarity
- [ ] 5.2.4.4 Target: pass@1 > 70%

### 5.2.5 Unit Tests

- [ ] **Task 5.2.5 Complete**

- [ ] Test MLM masking creates valid spans
- [ ] Test FIM splitting produces valid triples
- [ ] Test generation produces syntactically valid code

---

## 5.3 Quality Classification Training

- [ ] **Section 5.3 Complete**

This section trains the Credo quality classification head, learning to detect code quality violations.

### 5.3.1 Credo Label Preparation

- [ ] **Task 5.3.1 Complete**

Prepare Credo violation labels for training.

- [ ] 5.3.1.1 Load Credo annotations from Phase 1
- [ ] 5.3.1.2 Convert to multi-hot encoding
- [ ] 5.3.1.3 Balance positive/negative examples
- [ ] 5.3.1.4 Create train/val splits

### 5.3.2 Quality Head Training

- [ ] **Task 5.3.2 Complete**

Train quality classification head.

- [ ] 5.3.3.1 Use binary cross-entropy per check
- [ ] 5.3.3.2 Weight by check frequency (rare checks get higher weight)
- [ ] 5.3.3.3 Train jointly with code generation
- [ ] 5.3.3.4 Monitor per-category accuracy

### 5.3.3 Quality Evaluation

- [ ] **Task 5.3.3 Complete**

Evaluate quality classification performance.

- [ ] 5.3.3.1 Compute precision/recall per check
- [ ] 5.3.3.2 Compute F1-score (macro and micro)
- [ ] 5.3.3.3 Compute category-level metrics
- [ ] 5.3.3.4 Target: macro F1 > 0.6

### 5.3.4 Unit Tests

- [ ] **Task 5.3.4 Complete**

- [ ] Test label encoding produces correct shapes
- [ ] Test quality head outputs multi-label predictions

---

## 5.4 Security Classification Training

- [ ] **Section 5.4 Complete**

This section trains the Sobelow security classification head, learning to detect security vulnerabilities.

### 5.4.1 Sobelow Label Preparation

- [ ] **Task 5.4.1 Complete**

Prepare Sobelow vulnerability labels.

- [ ] 5.4.1.1 Load Sobelow annotations from Phase 1
- [ ] 5.4.1.2 Convert to multi-hot encoding
- [ ] 5.4.1.3 Map to CWE categories
- [ ] 5.4.1.4 Create train/val splits

### 5.4.2 Security Head Training

- [ ] **Task 5.4.2 Complete**

Train security classification head.

- [ ] 5.4.2.1 Use binary cross-entropy per vulnerability
- [ ] 5.4.2.2 Weight by severity (high severity gets higher weight)
- [ ] 5.4.2.3 Train jointly with other tasks
- [ ] 5.4.2.4 Monitor per-CWE accuracy

### 5.4.3 Security Evaluation

- [ ] **Task 5.4.3 Complete**

Evaluate security classification performance.

- [ ] 5.4.3.1 Compute precision/recall per vulnerability
- [ ] 5.4.3.2 Compute F1-score (macro and micro)
- [ ] 5.4.3.3 Compute CWE-level metrics
- [ ] 5.4.3.4 Target: macro F1 > 0.5

### 5.4.4 Unit Tests

- [ ] **Task 5.4.4 Complete**

- [ ] Test Sobelow label encoding
- [ ] Test security head outputs predictions

---

## 5.5 Test Generation Training

- [ ] **Section 5.5 Complete**

This section trains the test generation head, learning to produce tests for given code and vice versa.

### 5.5.1 Test Pair Preparation

- [ ] **Task 5.5.1 Complete**

Prepare code-test pair training data.

- [ ] 5.5.1.1 Load pairs from Phase 1
- [ ] 5.5.1.2 Create bidirectional examples (code→test, test→code)
- [ ] 5.5.1.3 Balance ExUnit, StreamData, LiveViewTest types
- [ ] 5.5.1.4 Add test-type tokens for conditioning

### 5.5.2 Test Head Training

- [ ] **Task 5.5.2 Complete**

Train test generation head.

- [ ] 5.5.2.1 Use cross-entropy loss for generation
- [ ] 5.5.2.2 Train both directions jointly
- [ ] 5.5.2.3 Condition on test type token
- [ ] 5.5.2.4 Monitor test validity (syntactic)

### 5.5.3 Test Evaluation

- [ ] **Task 5.5.3 Complete**

Evaluate test generation quality.

- [ ] 5.5.3.1 Compute test pass@1 (generated test passes on code)
- [ ] 5.5.3.2 Compute mutation score (with Muzak integration)
- [ ] 5.5.3.3 Compute test coverage
- [ ] 5.5.3.4 Target: pass@1 > 60%

### 5.5.4 Unit Tests

- [ ] **Task 5.5.4 Complete**

- [ ] Test bidirectional training examples
- [ ] Test conditioning on test type

### 5.5.5 Execution Feedback with Muzak

- [ ] **Task 5.5.5 Complete**

Implement reinforcement learning from mutation testing feedback.

- [ ] 5.5.5.1 Implement `ElixirCoder.Testing.Muzak.reward/2`
- [ ] 5.5.5.2 Parse mutation scores from Muzak CLI output
- [ ] 5.5.5.3 Format: "X mutations run - Y mutations survived" → reward = (X-Y)/X
- [ ] 5.5.5.4 Handle Muzak Pro parallel execution for faster feedback
- [ ] 5.5.5.5 Implement policy gradient: ∇θ J(θ) ≈ Σ (reward - baseline) * ∇θ log π(test|code)
- [ ] 5.5.5.6 Use baseline subtraction to reduce variance

### 5.5.6 Mutation Caching

- [ ] **Task 5.5.6 Complete**

Implement caching for expensive Muzak execution.

- [ ] 5.5.6.1 Create `:ets` table for mutation result cache
- [ ] 5.5.6.2 Cache key: `{code_hash, test_hash, muzak_version}`
- [ ] 5.5.6.3 Implement `ElixirCoder.Testing.Muzak.cached_run/3`
- [ ] 5.5.6.4 Return cached results if available, fresh < 24 hours
- [ ] 5.5.6.5 Implement cache warming for common patterns

### 5.5.7 RL Fine-Tuning Loop

- [ ] **Task 5.5.7 Complete**

Implement CodeRL-style reinforcement learning fine-tuning.

- [ ] 5.5.7.1 Implement `ElixirCoder.Testing.RL.finetune/3`
- [ ] 5.5.7.2 Load pre-trained test generation checkpoint
- [ ] 5.5.7.3 Generate multiple test candidates per code example (beam search)
- [ ] 5.5.7.4 Score each candidate with Muzak (cached when possible)
- [ ] 5.5.7.5 Apply policy gradient update using rewards as weights
- [ ] 5.5.7.6 Sample mutations during early training (50 vs 1000)
- [ ] 5.5.7.7 Increase to full mutations during final epochs

### 5.5.8 Unit Tests

- [ ] **Task 5.5.8 Complete**

- [ ] Test Muzak reward computation parses CLI output
- [ ] Test cache hit/miss behavior
- [ ] Test RL loop updates model parameters
- [ ] Test mutation sampling speeds up early training
- [ ] Test beam search generates diverse candidates

---

## 5.6 Clarification Training

- [ ] **Section 5.6 Complete**

This section trains the clarification system, learning when to ask questions and what to ask.

### 5.6.1 Ambiguity Dataset

- [ ] **Task 5.6.1 Complete**

Prepare ambiguity detection dataset.

- [ ] 5.6.1.1 Create ambiguous prompt examples
- [ ] 5.6.1.2 Create clear prompt examples
- [ ] 5.6.1.3 Label: needs_clarification (binary)
- [ ] 5.6.1.4 Include ground-truth questions for ambiguous cases

### 5.6.2 Detection Head Training

- [ ] **Task 5.6.2 Complete**

Train binary clarification detection head.

- [ ] 5.6.2.1 Use binary cross-entropy loss
- [ ] 5.6.2.2 Train on labeled ambiguous/clear examples
- [ ] 5.6.2.3 Balance positive/negative examples
- [ ] 5.6.2.4 Target: precision > 0.7 (avoid over-asking)

### 5.6.3 Question Generation Training

- [ ] **Task 5.6.3 Complete**

Train question generation head.

- [ ] 5.6.3.1 Generate questions for ambiguous examples
- [ ] 5.6.3.2 Use cross-entropy loss
- [ ] 5.6.3.3 Condition on detected ambiguity type
- [ ] 5.6.3.4 Monitor question relevance

### 5.6.4 EVPI-Based Question Ranking

- [ ] **Task 5.6.4 Complete**

Implement Expected Value of Perfect Information (EVPI) ranking for questions.

- [ ] 5.6.4.1 Implement `ElixirCoder.Clarification.EVPI.compute/3`
- [ ] 5.6.4.2 Estimate information gain: H[outcome|ask] - H[outcome|proceed]
- [ ] 5.6.4.3 Use multi-sample divergence as uncertainty proxy
- [ ] 5.6.4.4 Score candidate questions by expected reduction in uncertainty
- [ ] 5.6.4.5 Rank questions: highest EVPI first
- [ ] 5.6.4.6 Apply semantic entropy for uncertainty quantification
- [ ] 5.6.4.7 Select top-N questions (default N=1 for single-round)

### 5.6.5 Clarification Evaluation

- [ ] **Task 5.6.5 Complete**

Evaluate clarification system.

- [ ] 5.6.5.1 Compute detection precision/recall
- [ ] 5.6.5.2 Compute question quality (human rated)
- [ ] 5.6.5.3 Compute Δpass@1 (with vs. without clarification)
- [ ] 5.6.5.4 Target: Δpass@1 > 5%

### 5.6.6 Unit Tests

- [ ] **Task 5.6.6 Complete**

- [ ] Test ambiguity detection labels
- [ ] Test question generation produces valid questions
- [ ] Test EVPI ranking selects most informative questions
- [ ] Test semantic entropy correlates with clarification value

---

## 5.7 Explanation Training

- [ ] **Section 5.7 Complete**

This section trains the explanation generation head, learning to produce natural language explanations for code quality and security issues.

### 5.7.1 Explanation Dataset

- [ ] **Task 5.7.1 Complete**

Prepare explanation training dataset.

- [ ] 5.7.1.1 Create code + issue → explanation examples
- [ ] 5.7.1.2 Use Credo/Sobelow documentation as ground truth
- [ ] 5.7.1.3 Generate synthetic explanations via LLM
- [ ] 5.7.1.4 Include chain-of-thought reasoning

### 5.7.2 Explanation Head Training

- [ ] **Task 5.7.2 Complete**

Train explanation generation head.

- [ ] 5.7.2.1 Use cross-entropy loss for generation
- [ ] 5.7.2.2 Condition on issue type (Credo check or Sobelow finding)
- [ ] 5.7.2.3 Train with RAG context (documentation)
- [ ] 5.7.2.4 Monitor explanation quality

### 5.7.3 Explanation Evaluation

- [ ] **Task 5.7.3 Complete**

Evaluate explanation generation quality.

- [ ] 5.7.3.1 Compute BLEU/ChrF against reference explanations
- [ ] 5.7.3.2 Human evaluation: accuracy, actionability
- [ ] 5.7.3.3 Test if explanation helps fix the issue
- [ ] 5.7.3.4 Target: human rating > 3.5/5

### 5.7.4 Unit Tests

- [ ] **Task 5.7.4 Complete**

- [ ] Test explanation dataset format
- [ ] Test explanation generation produces text

---

## 5.8 Reinforcement Learning

- [ ] **Section 5.8 Complete**

This section implements reinforcement learning with execution feedback from Muzak mutation testing.

### 5.8.1 Reward Computation

- [ ] **Task 5.8.1 Complete**

Implement reward computation from mutation testing.

- [ ] 5.8.1.1 Implement `ElixirCoder.Training.RL.MuzakReward.compute/2`
- [ ] 5.8.1.2 Run Muzak on generated tests
- [ ] 5.8.1.3 Calculate mutation kill rate
- [ ] 5.8.1.4 Return scalar reward (0.0 to 1.0)

### 5.8.2 Policy Gradient Training

- [ ] **Task 5.8.2 Complete**

Implement REINFORCE-style policy gradient.

- [ ] 5.8.2.1 Implement `ElixirCoder.Training.RL.PolicyGradient.step/4`
- [ ] 5.8.2.2 Generate test samples
- [ ] 5.8.2.3 Compute rewards via Muzak
- [ ] 5.8.2.4 Update policy: ∇J = Σ(reward * ∇log p)

### 5.8.3 PPO Integration

- [ ] **Task 5.8.3 Complete**

Implement Proximal Policy Optimization.

- [ ] 5.8.3.1 Implement clipped surrogate objective
- [ ] 5.8.3.2 Compute importance sampling ratio
- [ ] 5.8.3.3 Apply KL penalty for policy stability
- [ ] 5.8.3.4 Train with multiple epochs per batch

### 5.8.4 RL Evaluation

- [ ] **Task 5.8.4 Complete**

Evaluate RL training effectiveness.

- [ ] 5.8.4.1 Compare mutation scores before/after RL
- [ ] 5.8.4.2 Monitor reward increase over time
- [ ] 5.8.4.3 Target: mutation score improvement > 10%

### 5.8.5 Unit Tests

- [ ] **Task 5.8.5 Complete**

- [ ] Test reward computation produces valid scores
- [ ] Test policy gradient updates parameters

---

## 5.9 Instruction Tuning for Conversational Code Generation

- [ ] **Section 5.9 Complete**

This section implements instruction tuning to enable conversational code generation, allowing users to interact with the model using natural language instructions like "write a fibonacci function" or "make it recursive". Following the approach used by StarCoder/OctoPack and CodeLlama-Instruct, we train on instruction-response pairs derived from multiple sources.

### 5.9.1 Training Data Mix Strategy

- [ ] **Task 5.9.1 Complete**

Define the balanced training mix for instruction tuning to preserve production code quality while learning conversational capabilities.

Based on research in `notes/research/1.06-rich-semantic-extraction/`, the instruction tuning phase uses a **70/20/10 split** to maintain code density while learning from instructional content:

| Source | Percentage | Rationale |
|--------|------------|-----------|
| Source code (continued) | 70% | Preserves production patterns, code density |
| Official docs/guides | 20% | Canonical patterns, Apache/MIT licensed |
| Curated tutorials | 10% | Instruction-response pairs, permissive license |

**Key principle**: Instruction tuning uses **lower learning rate** (1e-5 vs 1e-4) to adapt without forgetting production patterns.

- [ ] 5.9.1.1 Implement `ElixirCoder.Instruction.Dataset.build_mix/2`
- [ ] 5.9.1.2 Sample from source corpus with 70% weight
- [ ] 5.9.1.3 Include official elixir-lang.org guides (Apache 2.0)
- [ ] 5.9.1.4 Include Elixir School tutorials (MIT licensed)
- [ ] 5.9.1.5 Include HexDocs @doc examples (permissive licenses only)
- [ ] 5.9.1.6 Filter by date: prefer content from 2020+
- [ ] 5.9.1.7 Track source attribution for each training example
- [ ] 5.9.1.8 Validate license compatibility for each source

**Avoiding "Tutorial Style" Leakage**:

To prevent the model from generating verbose, tutorial-style code instead of production code:

- [ ] 5.9.1.9 Apply style-aware weighting: production examples 2x weight
- [ ] 5.9.1.10 Include "style labels" for style-discriminated training
- [ ] 5.9.1.11 Evaluate for verbosity: reject code with >30% comment ratio
- [ ] 5.9.1.12 Target: production-style code in 80%+ of generation outputs

### 5.9.2 Official Documentation Extraction

- [ ] **Task 5.9.2 Complete**

Extract instruction-response pairs from official Elixir documentation.

- [ ] 5.9.2.1 Implement `ElixirCoder.Instruction.Docs.extract_from_hexdocs/1`
- [ ] 5.9.2.2 Parse @doc and @moduledoc examples from HexDocs
- [ ] 5.9.2.3 Extract: explanation text → code example pairs
- [ ] 5.9.2.4 Include elixir-lang.org/guides (Getting Started, etc.)
- [ ] 5.9.2.5 Include OTP design principles documentation
- [ ] 5.9.2.6 Filter for Apache/MIT licensed content only
- [ ] 5.9.2.7 Target: 50,000+ doc example pairs

### 5.9.3 Commit Message Instruction Extraction

- [ ] **Task 5.9.3 Complete**

Extract instruction-response pairs from Git commit messages.

- [ ] 5.9.3.1 Implement `ElixirCoder.Instruction.Git.extract_pairs/1` cloning repos
- [ ] 5.9.3.2 Parse commit history with `git log --pretty=format:"%H %s"`
- [ ] 5.9.3.3 Extract diff between commits: `git show {commit}`
- [ ] 5.9.3.4 Create pairs: `{instruction: commit_message, response: code_diff}`
- [ ] 5.9.3.5 Filter meaningful commits (exclude "update readme", "merge branch")
- [ ] 5.9.3.6 Clean commit messages (remove issue numbers, ticket references)
- [ ] 5.9.3.7 Target: 100,000+ instruction pairs from Elixir repos

### 5.9.4 StackOverflow Q&A Extraction

- [ ] **Task 5.9.4 Complete**

Extract question-answer pairs from StackOverflow Elixir questions.

- [ ] 5.9.4.1 Implement `ElixirCoder.Instruction.StackExchange.scrape/2`
- [ ] 5.9.4.2 Use StackExchange API with `elixir` tag filter
- [ ] 5.9.4.3 Extract question title + body as instruction
- [ ] 5.9.4.4 Extract accepted answer as response
- [ ] 5.9.4.5 Include code blocks from both question and answer
- [ ] 5.9.4.6 Filter for questions with code answers
- [ ] 5.9.4.7 Target: 50,000+ Elixir-specific Q&A pairs

### 5.9.5 Synthetic Instruction Generation

- [ ] **Task 5.9.5 Complete**

Generate synthetic instruction-response pairs using GPT-4/Claude.

- [ ] 5.9.5.1 Implement `ElixirCoder.Instruction.Synthetic.generate/2`
- [ ] 5.9.5.2 Sample code from training corpus
- [ ] 5.9.5.3 Prompt: "Write a natural language instruction to generate this code"
- [ ] 5.9.5.4 Validate instruction quality (relevance, specificity)
- [ ] 5.9.5.5 Generate follow-up instructions: "make it tail-recursive", "add error handling"
- [ ] 5.9.5.6 Target: 200,000+ synthetic pairs

### 5.9.6 Multi-Turn Dialogue Construction

- [ ] **Task 5.9.6 Complete**

Construct multi-turn conversational datasets for chat-like interaction.

- [ ] 5.9.6.1 Implement `ElixirCoder.Instruction.Dialogue.build_multi_turn/1`
- [ ] 5.9.6.2 Create conversation templates: request → code → follow-up → code
- [ ] 5.9.6.3 Common Elixir follow-ups:
  - "make it tail recursive"
  - "add error handling"
  - "use pattern matching"
  - "convert to GenServer"
  - "add typespecs"
- [ ] 5.9.6.4 Chain 2-4 turns per conversation
- [ ] 5.9.6.5 Include dialogue history in training format
- [ ] 5.9.6.6 Target: 50,000+ multi-turn conversations

### 5.9.7 Dialogue Format Template

- [ ] **Task 5.9.7 Complete**

Define the training format for conversational interactions.

- [ ] 5.9.7.1 Design ChatML-style format with roles (user, assistant, system)
- [ ] 5.9.7.2 Format:
  ```
  <system>You are an expert Elixir developer...</system>
  <user>Write a fibonacci function</user>
  <assistant>```elixir\ndef fib(n)...```</assistant>
  <user>Make it tail recursive</user>
  <assistant>```elixir\ndefp fib_tail...</assistant>
  ```
- [ ] 5.9.7.3 Add special tokens for code blocks
- [ ] 5.9.7.4 Support ontology injection in system prompt
- [ ] 5.9.7.5 Implement `ElixirCoder.Instruction.Format.encode/1`

### 5.9.8 Conversational Fine-Tuning

- [ ] **Task 5.9.8 Complete**

Fine-tune the model on instruction-response data.

- [ ] 5.9.8.1 Implement `ElixirCoder.Instruction.Trainer.finetune/2`
- [ ] 5.9.8.2 Load pre-trained checkpoint from Phase 1 (code-only)
- [ ] 5.9.8.3 Use supervised fine-tuning with cross-entropy loss
- [ ] 5.9.8.4 Apply 70/20/10 training mix (see 5.9.1)
- [ ] 5.9.8.5 Learning rate: 1e-5 (10x lower than pre-training)
- [ ] 5.9.8.6 Train for 3-5 epochs
- [ ] 5.9.8.7 Target: instruction-following accuracy > 80%

### 5.9.9 Conversational Context Management

- [ ] **Task 5.9.9 Complete**

Implement context window management for multi-turn conversations.

- [ ] 5.9.9.1 Implement `ElixirCoder.Instruction.Context.compress/2`
- [ ] 5.9.9.2 Truncate old turns when exceeding context window
- [ ] 5.9.9.3 Keep system prompt + N recent turns
- [ ] 5.9.9.4 Implement sliding window for long conversations
- [ ] 5.9.9.5 Cache conversation context in process dictionary
- [ ] 5.9.9.6 Support context sizes: 4K, 8K, 16K tokens

### 5.9.10 Follow-Up Request Detection

- [ ] **Task 5.9.10 Complete**

Detect and classify follow-up requests in conversational context.

- [ ] 5.9.10.1 Implement `ElixirCoder.Instruction.FollowUp.detect/2`
- [ ] 5.9.10.2 Classify follow-up types:
  - Code modification ("make it recursive", "add error handling")
  - Code extension ("also handle empty list", "add a nil check")
  - Code explanation ("how does this work", "why use process dictionary")
  - New task ("now write a GenServer", "add a supervisor")
- [ ] 5.9.10.3 Train classifier on multi-turn conversations
- [ ] 5.9.10.4 Use binary cross-entropy for classification
- [ ] 5.9.10.5 Target: follow-up classification F1 > 0.85

### 5.9.11 Code Editing vs Generation

- [ ] **Task 5.9.11 Complete**

Support both full-code generation and incremental editing.

- [ ] 5.9.11.1 Implement `ElixirCoder.Instruction.Edit.apply/3`
- [ ] 5.9.11.2 Parse previous code from conversation history
- [ ] 5.9.11.3 Generate edits (replacements, insertions, deletions)
- [ ] 5.9.11.4 Format: `@@ -old +new @@` unified diff format
- [ ] 5.9.11.5 Apply edits to previous code
- [ ] 5.9.11.6 Validate edited code compiles correctly
- [ ] 5.9.11.7 Mix training: 70% generation, 30% editing

### 5.9.12 Instruction Following Evaluation

- [ ] **Task 5.9.12 Complete**

Evaluate instruction-following capabilities.

- [ ] 5.9.12.1 Implement `ElixirCoder.Instruction.Eval.evaluate/2`
- [ ] 5.9.12.2 Human evaluation: 500 random instructions from test set
- [ ] 5.9.12.3 Metrics: code compiles, matches intent, style consistency
- [ ] 5.9.12.4 Automatic: instruction-passing rate (executes without error)
- [ ] 5.9.12.5 Multi-turn: success rate for follow-up requests
- [ ] 5.9.12.6 Target: instruction-passing > 75%, follow-up success > 65%

### 5.9.13 Unit Tests

- [ ] **Task 5.9.13 Complete**

- [ ] Test commit extraction produces valid instruction-response pairs
- [ ] Test StackOverflow scraping extracts Q&A correctly
- [ ] Test synthetic generation produces quality instructions
- [ ] Test multi-turn format handles conversation history
- [ ] Test context compression preserves relevant information
- [ ] Test follow-up detection classifies correctly
- [ ] Test code editing produces valid modifications

---

## 5.10 Training Monitoring

- [ ] **Section 5.10 Complete**

This section implements comprehensive training monitoring and analysis.

### 5.10.1 Metric Dashboard

- [ ] **Task 5.10.1 Complete**

Create training metrics dashboard.

- [ ] 5.10.1.1 Implement live metric tracking
- [ ] 5.10.1.2 Display: loss, per-task metrics, throughput
- [ ] 5.10.1.3 Generate plots: loss curves, metric trends
- [ ] 5.10.1.4 Export to HTML for viewing

### 5.10.2 Error Analysis

- [ ] **Task 5.10.2 Complete**

Implement error analysis tools.

- [ ] 5.10.2.1 Track examples where model fails
- [ ] 5.10.2.2 Categorize failure types
- [ ] 5.10.2.3 Generate error report
- [ ] 5.10.2.4 Identify underperforming categories

### 5.10.3 Hyperparameter Logging

- [ ] **Task 5.10.3 Complete**

Log all training hyperparameters.

- [ ] 5.10.3.1 Create `training_config.json`
- [ ] 5.10.3.2 Include: model config, optimizer, schedule
- [ ] 5.10.3.3 Include: data paths, seed, random state
- [ ] 5.10.3.4 Save with final model

### 5.10.4 Training Report

- [ ] **Task 5.10.4 Complete**

Generate comprehensive training report.

- [ ] 5.10.4.1 Document all training phases
- [ ] 5.10.4.2 Include final metrics per task
- [ ] 5.10.4.3 Include: epochs, time, throughput
- [ ] 5.10.4.4 Save to `data/reports/training-{timestamp}.md`

---

## Success Criteria

1. **Code Generation**: pass@1 > 70% on validation set
2. **Quality Classification**: macro F1 > 0.6 on Credo checks
3. **Security Classification**: macro F1 > 0.5 on Sobelow findings
4. **Test Generation**: pass@1 > 60%, mutation score improvement > 10%
5. **Clarification**: Δpass@1 > 5% with clarification
6. **Explanation**: human rating > 3.5/5

## Provides Foundation

This phase produces the trained model for:
- **Phase 6**: Inference pipeline deployment
- **Phase 7**: Evaluation and optimization
