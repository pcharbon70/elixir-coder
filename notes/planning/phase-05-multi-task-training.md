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

### 5.6.4 Clarification Evaluation

- [ ] **Task 5.6.4 Complete**

Evaluate clarification system.

- [ ] 5.6.4.1 Compute detection precision/recall
- [ ] 5.6.4.2 Compute question quality (human rated)
- [ ] 5.6.4.3 Compute Δpass@1 (with vs. without clarification)
- [ ] 5.6.4.4 Target: Δpass@1 > 5%

### 5.6.5 Unit Tests

- [ ] **Task 5.6.5 Complete**

- [ ] Test ambiguity detection labels
- [ ] Test question generation produces valid questions

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

## 5.9 Training Monitoring

- [ ] **Section 5.9 Complete**

This section implements comprehensive training monitoring and analysis.

### 5.9.1 Metric Dashboard

- [ ] **Task 5.9.1 Complete**

Create training metrics dashboard.

- [ ] 5.9.1.1 Implement live metric tracking
- [ ] 5.9.1.2 Display: loss, per-task metrics, throughput
- [ ] 5.9.1.3 Generate plots: loss curves, metric trends
- [ ] 5.9.1.4 Export to HTML for viewing

### 5.9.2 Error Analysis

- [ ] **Task 5.9.2 Complete**

Implement error analysis tools.

- [ ] 5.9.2.1 Track examples where model fails
- [ ] 5.9.2.2 Categorize failure types
- [ ] 5.9.2.3 Generate error report
- [ ] 5.9.2.4 Identify underperforming categories

### 5.9.3 Hyperparameter Logging

- [ ] **Task 5.9.3 Complete**

Log all training hyperparameters.

- [ ] 5.9.3.1 Create `training_config.json`
- [ ] 5.9.3.2 Include: model config, optimizer, schedule
- [ ] 5.9.3.3 Include: data paths, seed, random state
- [ ] 5.9.3.4 Save with final model

### 5.9.4 Training Report

- [ ] **Task 5.9.4 Complete**

Generate comprehensive training report.

- [ ] 5.9.4.1 Document all training phases
- [ ] 5.9.4.2 Include final metrics per task
- [ ] 5.9.4.3 Include: epochs, time, throughput
- [ ] 5.9.4.4 Save to `data/reports/training-{timestamp}.md`

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
