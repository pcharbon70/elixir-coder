# Phase 4: Training Infrastructure

## Overview

Phase 4 implements the training infrastructure that enables efficient model training on the prepared corpus. By the end of this phase, we will have a complete training pipeline with data loading, loss computation, optimization, checkpointing, and logging.

The design prioritizes training efficiency and debugging capability. We use Axon.Loop for training orchestration, EXLA for GPU acceleration, and implement custom callbacks for curriculum learning progress and multi-task loss balancing.

This phase establishes the training infrastructure that will be used in Phase 5 for actual multi-task training, with careful attention to memory efficiency, reproducibility, and monitoring.

---

## 4.1 Data Loading Pipeline

- [ ] **Section 4.1 Complete**

This section implements efficient data loading that can keep the GPU fed with batches during training, supporting shuffling, prefetching, and multiple workers.

### 4.1.1 Dataset Reader

- [ ] **Task 4.1.1 Complete**

Implement reading of tokenized dataset from disk.

- [ ] 4.1.1.1 Implement `ElixirCoder.Training.Data.read_dataset/2`
- [ ] 4.1.1.2 Read from `data/tokenized/{split}.bin`
- [ ] 4.1.1.3 Support streaming to avoid loading full dataset
- [ ] 4.1.1.4 Return stream of samples (ids, mask, labels)

### 4.1.2 Batch Sampler

- [ ] **Task 4.1.2 Complete**

Implement batch sampling with shuffling.

- [ ] 4.1.2.1 Implement `ElixirCoder.Training.Data.BatchSampler.new/2`
- [ ] 4.1.2.2 Random shuffle each epoch
- [ ] 4.1.2.3 Support drop_last for fixed batch size
- [ ] 4.1.2.4 Support distributed sampling for multi-GPU (future)

### 4.1.3 Collation

- [ ] **Task 4.1.3 Complete**

Implement batch collation from individual samples.

- [ ] 4.1.3.1 Implement `ElixirCoder.Training.Data.collate/2`
- [ ] 4.1.3.2 Stack tensors along batch dimension
- [ ] 4.1.3.3 Create attention masks (1 for real, 0 for padding)
- [ ] 4.1.3.4 Handle variable sequence lengths with padding

### 4.1.4 Prefetch Stream

- [ ] **Task 4.1.4 Complete**

Implement prefetching for GPU throughput.

- [ ] 4.1.4.1 Implement `ElixirCoder.Training.Data.prefetch_stream/3`
- [ ] 4.1.4.2 Use `Task.Supervisor` for async prefetch
- [ ] 4.1.4.3 Maintain prefetch queue (default 2 batches)
- [ ] 4.1.4.4 Ensure blocking when queue full (backpressure)

### 4.1.5 DataLoader

- [ ] **Task 4.1.5 Complete**

Implement complete data pipeline.

- [ ] 4.1.5.1 Implement `ElixirCoder.Training.Data.DataLoader` struct
- [ ] 4.1.5.2 Implement `new/2` creating loader from dataset path
- [ ] 4.1.5.3 Implement `stream/1` returning infinite batch stream
- [ ] 4.1.5.4 Support batch_size, shuffle, prefetch, drop_last options

### 4.1.6 Unit Tests

- [ ] **Task 4.1.6 Complete**

- [ ] Test dataset reader produces valid tensors
- [ ] Test batch sampler shuffles correctly
- [ ] Test collation produces consistent batch shapes
- [ ] Test prefetch stream yields batches asynchronously
- [ ] Test DataLoader integrates all components

---

## 4.2 Loss Functions

- [ ] **Section 4.2 Complete**

This section implements the loss functions for each task and the weighted combination for multi-task training.

### 4.2.1 Cross-Entropy Loss

- [ ] **Task 4.2.1 Complete**

Implement cross-entropy loss for generation tasks.

- [ ] 4.2.1.1 Implement `ElixirCoder.Training.Loss.cross_entropy/2`
- [ ] 4.2.1.2 Use Nx.Defn for differentiable computation
- [ ] 4.2.1.3 Support label smoothing (optional, default 0.0)
- [ ] 4.2.1.4 Apply mask to ignore padding tokens

### 4.2.2 Binary Cross-Entropy Loss

- [ ] **Task 4.2.2 Complete**

Implement binary cross-entropy for binary classification.

- [ ] 4.2.2.1 Implement `ElixirCoder.Training.Loss.binary_cross_entropy/2`
- [ ] 4.2.2.2 Use sigmoid + log for numerical stability
- [ ] 4.2.2.3 Support logits input (no sigmoid applied outside)
- [ ] 4.2.2.4 Return scalar loss

### 4.2.3 Multi-Label Classification Loss

- [ ] **Task 4.2.3 Complete**

Implement binary cross-entropy for multi-label (Credo/Sobelow).

- [ ] 4.2.3.1 Implement `ElixirCoder.Training.Loss.multi_label_bce/2`
- [ ] 4.2.3.2 Apply sigmoid + log per label
- [ ] 4.2.3.3 Mean over all labels
- [ ] 4.2.3.4 Support label weighting

### 4.2.4 Multi-Task Loss

- [ ] **Task 4.2.4 Complete**

Implement weighted combination of all task losses.

- [ ] 4.2.4.1 Implement `ElixirCoder.Training.Loss.multi_task_loss/2`
- [ ] 4.2.4.2 Accept map of task_name -> {predictions, targets}
- [ ] 4.2.4.3 Accept map of task_name -> weight
- [ ] 4.2.4.4 Return weighted sum: Σ(weight_i * loss_i)

### 4.2.5 Loss Weights

- [ ] **Task 4.2.5 Complete**

Define initial loss weights for multi-task training.

- [ ] 4.2.5.1 Define `ElixirCoder.Training.Loss.default_weights/0`
- [ ] 4.2.5.2 Set code_generation: 1.0 (primary task)
- [ ] 4.2.5.3 Set quality: 0.5, security: 0.5 (secondary)
- [ ] 4.2.5.4 Set test_generation: 0.8, clarification: 0.3, explanation: 0.3
- [ ] 4.2.5.5 Document rationale for weight choices

### 4.2.6 Uncertainty-Based Loss Weighting

- [ ] **Task 4.2.6 Complete**

Implement adaptive loss weighting based on task uncertainty (Kendall et al.).

- [ ] 4.2.6.1 Implement `ElixirCoder.Training.Loss.uncertainty_weighted/2`
- [ ] 4.2.6.2 Track task loss variance over training window
- [ ] 4.2.6.3 Increase weight for high-uncertainty (noisy) tasks
- [ ] 4.2.6.4 Decrease weight for low-uncertainty (learned) tasks
- [ ] 4.2.6.5 Use learned homoscedastic uncertainty parameters
- [ ] 4.2.6.6 Apply log variance scaling: loss / (2 * σ²) + log(σ)

### 4.2.7 GradNorm for Gradient Balancing

- [ ] **Task 4.2.7 Complete**

Implement GradNorm for gradient magnitude balancing across tasks.

- [ ] 4.2.7.1 Implement `ElixirCoder.Training.Loss.gradnorm_weights/3`
- [ ] 4.2.7.2 Track gradient norms per task during training
- [ ] 4.2.7.3 Compute relative gradient rates: r_i = ||g_i|| / G_target
- [ ] 4.2.7.4 Adjust task weights to balance gradient magnitudes
- [ ] 4.2.7.5 Apply as Axon.Loop callback every N steps

### 4.2.8 Unit Tests

- [ ] **Task 4.2.8 Complete**

- [ ] Test cross-entropy loss produces valid gradients
- [ ] Test BCE loss handles logits correctly
- [ ] Test multi-label loss averages correctly
- [ ] Test multi-task loss combines with weights
- [ ] Test uncertainty weighting adapts correctly
- [ ] Test GradNorm balances gradients across tasks
- [ ] Test loss values are reasonable (not NaN, not extreme)

---

## 4.3 Contrastive Learning Infrastructure

- [ ] **Section 4.3 Complete**

This section implements contrastive learning infrastructure for quality-aware training, teaching the model to distinguish clean code from violating code in embedding space.

Research from ContraCode (Jain et al., EMNLP 2021) demonstrates that contrastive pre-training significantly improves code understanding. For Credo-specific training, we generate pairs programmatically and use InfoNCE loss to pull clean code representations away from violating variants.

### 4.3.1 Contrastive Pair Generation

- [ ] **Task 4.3.1 Complete**

Implement generation of clean/violating code pairs for contrastive training.

- [ ] 4.3.1.1 Implement `ElixirCoder.Training.Contrastive.generate_pairs/2`
- [ ] 4.3.1.2 Load clean code from training corpus
- [ ] 4.3.1.3 Inject violations for each Credo rule type
- [ ] 4.3.1.4 Create triple: `{clean_code, violating_code, rule_type}`
- [ ] 4.3.1.5 Generate multiple violating variants per clean example
- [ ] 4.3.1.6 Store to `data/processed/contrastive_pairs.jsonl`

### 4.3.2 Violation Injection Strategies

- [ ] **Task 4.3.2 Complete**

Implement programmatic violation injection for common Credo rules.

- [ ] 4.3.2.1 Implement `ElixirCoder.Training.Contrastive.inject_io_inspect/1`
- [ ] 4.3.2.2 Implement `ElixirCoder.Training.Contrastive.inject_nesting/2` (wrap conditions)
- [ ] 4.3.2.3 Implement `ElixirCoder.Training.Contrastive.inject_long_lines/2`
- [ ] 4.3.2.4 Implement `ElixirCoder.Training.Contrastive.inject_complexity/2` (cyclomatic)
- [ ] 4.3.2.5 Ensure violating code remains syntactically valid
- [ ] 4.3.2.6 Validate with Code.string_to_quoted/1

### 4.3.3 InfoNCE Loss Implementation

- [ ] **Task 4.3.3 Complete**

Implement InfoNCE loss for contrastive learning.

- [ ] 4.3.3.1 Implement `ElixirCoder.Training.Loss.info_nce/4` in Nx.Defn
- [ ] 4.3.3.2 Compute similarity: sim(anchor, positive) / temperature
- [ ] 4.3.3.3 Compute similarities with negatives
- [ ] 4.3.3.4 Apply log-softmax: -log(exp(pos) / (exp(pos) + Σ exp(neg)))
- [ ] 4.3.3.5 Return scalar loss for optimization
- [ ] 4.3.3.6 Support temperature parameter (default 0.07)

### 4.3.4 Contrastive Batch Construction

- [ ] **Task 4.3.4 Complete**

Implement batch construction for contrastive training.

- [ ] 4.3.4.1 Implement `ElixirCoder.Training.Contrastive.batch_sampler/2`
- [ ] 4.3.4.2 Sample anchor (clean code) examples
- [ ] 4.3.4.3 Sample positive (same anchor, different view)
- [ ] 4.3.4.4 Sample multiple negatives (different violating examples)
- [ ] 4.3.4.5 Return batch: {anchors, positives, negatives}
- [ ] 4.3.4.6 Balance negative types across rules

### 4.3.5 Curriculum by Rule Complexity

- [ ] **Task 4.3.5 Complete**

Implement curriculum ordering by Credo rule difficulty.

- [ ] 4.3.5.1 Define rule difficulty tiers:
  - Tier 1: FunctionNames, ModuleNaming, IoInspect (surface patterns)
  - Tier 2: ModuleDoc, AliasOrder, MaxLineLength (structural)
  - Tier 3: Nesting, CyclomaticComplexity, CondStatements (cross-function)
  - Tier 4: DuplicatedCode, AliasUsage, Consistency (corpus-level)
- [ ] 4.3.5.2 Implement `ElixirCoder.Training.Contrastive.rule_difficulty/1`
- [ ] 4.3.5.3 Order training: Tier 1 → Tier 2 → Tier 3 → Tier 4
- [ ] 4.3.5.4 Spend N epochs per tier before progressing
- [ ] 4.3.5.5 Create hybrid: expand window (keep earlier tiers in mix)

### 4.3.6 Security Contrastive Learning

- [ ] **Task 4.3.6 Complete**

Implement contrastive learning for Sobelow security pairs.

- [ ] 4.3.6.1 Implement `ElixirCoder.Training.Contrastive.security_pairs/2`
- [ ] 4.3.6.2 Load secure code from training corpus
- [ ] 4.3.6.3 Inject vulnerabilities: SQLi, XSS, traversal, etc.
- [ ] 4.3.6.4 Create triple: `{secure_code, vulnerable_code, cwe_id}`
- [ ] 4.3.6.5 Use same InfoNCE loss with security-specific negatives
- [ ] 4.3.6.6 Store to `data/processed/security_contrastive.jsonl`

### 4.3.7 Integration with Multi-Task Training

- [ ] **Task 4.3.7 Complete**

Integrate contrastive learning with primary training objectives.

- [ ] 4.3.7.1 Implement `ElixirCoder.Training.Loss.contrastive_multi_task/2`
- [ ] 4.3.7.2 Combine InfoNCE loss with primary cross-entropy
- [ ] 4.3.7.3 Weight: α * primary_loss + β * contrastive_loss
- [ ] 4.3.7.4 Set α=1.0, β=0.3 initially
- [ ] 4.3.7.5 Adjust β based on validation quality metrics
- [ ] 4.3.7.6 Enable/disable via `use_contrastive: true` config

### 4.3.8 Unit Tests

- [ ] **Task 4.3.8 Complete**

- [ ] Test pair generation produces valid clean/violating pairs
- [ ] Test violation injection creates realistic Credo violations
- [ ] Test InfoNCE loss produces correct gradients
- [ ] Test batch sampler includes proper positives/negatives
- [ ] Test curriculum orders by difficulty tier
- [ ] Test security pairs represent actual vulnerabilities
- [ ] Test multi-task loss combines correctly

---

## 4.4 Optimizer and Scheduler

- [ ] **Section 4.4 Complete**

This section implements the optimizer and learning rate schedule for training.

### 4.4.1 Optimizer Configuration

- [ ] **Task 4.4.1 Complete**

Configure AdamW optimizer with weight decay.

- [ ] 4.4.1.1 Implement `ElixirCoder.Training.Optimizer.config/2`
- [ ] 4.4.1.2 Use Polaris.Optimizers (or Axon defaults)
- [ ] 4.4.1.3 Set lr: 3.0e-4, betas: {0.9, 0.999}, eps: 1.0e-8
- [ ] 4.4.1.4 Set weight_decay: 0.01 for AdamW
- [ ] 4.4.1.5 Support configurable learning rate

### 4.4.2 Learning Rate Schedule

- [ ] **Task 4.4.2 Complete**

Implement learning rate warmup and decay.

- [ ] 4.4.2.1 Implement `ElixirCoder.Training.Schedule.warmup_cosine/3`
- [ ] 4.4.2.2 Linear warmup for first N steps (default 2000)
- [ ] 4.4.2.3 Cosine decay to min_lr (10% of max)
- [ ] 4.4.2.4 Return lr as function of step

### 4.4.3 Scheduler Integration

- [ ] **Task 4.4.3 Complete**

Integrate LR schedule with Axon.Loop.

- [ ] 4.4.3.1 Implement `ElixirCoder.Training.Schedule.init/3`
- [ ] 4.4.3.2 Create `:agent` to track current step
- [ ] 4.4.3.3 Implement Axon.Loop callback for LR updates
- [ ] 4.4.3.4 Update optimizer state each step

### 4.4.4 Gradient Clipping

- [ ] **Task 4.4.4 Complete**

Implement gradient clipping for training stability.

- [ ] 4.4.4.1 Implement `ElixirCoder.Training.Optimizer.clip_gradients/2`
- [ ] 4.4.4.2 Clip by global norm (max_norm: 1.0)
- [ ] 4.4.4.3 Apply before optimizer update
- [ ] 4.4.4.4 Implement as Axon.Loop transformation

### 4.4.5 Unit Tests

- [ ] **Task 4.4.5 Complete**

- [ ] Test optimizer initializes correctly
- [ ] Test LR schedule warms up then decays
- [ ] Test gradient clipping prevents explosions
- [ ] Test scheduler updates LR through training

---

## 4.5 Training Loop

- [ ] **Section 4.5 Complete**

This section implements the main training loop using Axon.Loop, integrating all components.

### 4.5.1 Loop Initialization

- [ ] **Task 4.5.1 Complete**

Initialize Axon.Loop for training.

- [ ] 4.5.1.1 Implement `ElixirCoder.Training.Loop.init/4`
- [ ] 4.5.1.2 Create loop with model and optimizer
- [ ] 4.5.1.3 Add loss function
- [ ] 4.5.1.4 Add metrics (accuracy, loss)
- [ ] 4.5.1.5 Set compiler: EXLA for GPU

### 4.5.2 Training Step

- [ ] **Task 4.5.2 Complete**

Define single training step computation.

- [ ] 4.5.2.1 Implement `ElixirCoder.Training.Loop.step_fn/3`
- [ ] 4.5.2.2 Forward pass through model
- [ ] 4.5.2.3 Compute loss for all active tasks
- [ ] 4.5.2.4 Backward pass and parameter update
- [ ] 4.5.2.5 Return updated state and metrics

### 4.5.3 Validation Loop

- [ ] **Task 4.5.3 Complete**

Implement validation pass for monitoring.

- [ ] 4.5.3.1 Implement `ElixirCoder.Training.Loop.validate/3`
- [ ] 4.5.3.2 Run forward pass without gradient computation
- [ ] 4.5.3.3 Compute validation loss and metrics
- [ ] 4.5.3.4 Return validation results

### 4.5.4 Epoch Management

- [ ] **Task 4.5.4 Complete**

Implement epoch-level orchestration.

- [ ] 4.5.4.1 Implement `ElixirCoder.Training.Loop.run_epoch/3`
- [ ] 4.5.4.2 Iterate over batches for one epoch
- [ ] 4.5.4.3 Accumulate metrics
- [ ] 4.5.4.4 Shuffle dataset after each epoch

### 4.5.5 Unit Tests

- [ ] **Task 4.5.5 Complete**

- [ ] Test loop initializes without errors
- [ ] Test training step updates parameters
- [ ] Test validation loop computes metrics
- [ ] Test epoch completes full dataset

---

## 4.6 Checkpointing

- [ ] **Section 4.6 Complete**

This section implements model checkpointing for resuming training and model selection.

### 4.6.1 Checkpoint Format

- [ ] **Task 4.6.1 Complete**

Define checkpoint serialization format.

- [ ] 4.6.1.1 Create `ElixirCoder.Training.Checkpoint` struct
- [ ] 4.6.1.2 Include: model parameters, optimizer state, epoch, step
- [ ] 4.6.1.3 Include: loss_weights, scheduler_state, config
- [ ] 4.6.1.4 Use Nx.serialize for efficient binary format

### 4.6.2 Save Checkpoint

- [ ] **Task 4.6.2 Complete**

Implement checkpoint saving.

- [ ] 4.6.2.1 Implement `ElixirCoder.Training.Checkpoint.save/2`
- [ ] 4.6.2.2 Serialize parameters to binary
- [ ] 4.6.2.3 Write to `data/checkpoints/model-{epoch}.ckpt`
- [ ] 4.6.2.4 Write metadata JSON alongside
- [ ] 4.6.2.5 Sync to disk before returning

### 4.6.3 Load Checkpoint

- [ ] **Task 4.6.3 Complete**

Implement checkpoint loading for resumption.

- [ ] 4.6.3.1 Implement `ElixirCoder.Training.Checkpoint.load/2`
- [ ] 4.6.3.2 Read binary and deserialize parameters
- [ ] 4.6.3.3 Restore optimizer state
- [ ] 4.6.3.4 Restore epoch/step counters
- [ ] 4.6.3.5 Validate model architecture matches

### 4.6.4 Automatic Checkpointing

- [ ] **Task 4.6.4 Complete**

Implement automatic checkpointing callback.

- [ ] 4.6.4.1 Implement `ElixirCoder.Training.Checkpoint.callback/1`
- [ ] 4.6.4.2 Save every N epochs (default 1)
- [ ] 4.6.4.3 Keep best K checkpoints by validation loss (default 3)
- [ ] 4.6.4.4 Delete old checkpoints to save disk space
- [ ] 4.6.4.5 Implement as Axon.Loop callback

### 4.6.5 Unit Tests

- [ ] **Task 4.6.5 Complete**

- [ ] Test checkpoint saves valid binary
- [ ] Test checkpoint loading restores parameters
- [ ] Test automatic checkpointing creates files
- [ ] Test old checkpoints are deleted

---

## 4.7 Logging and Monitoring

- [ ] **Section 4.7 Complete**

This section implements training progress logging and monitoring for debugging and analysis.

### 4.7.1 Metrics Tracking

- [ ] **Task 4.7.1 Complete**

Implement metrics computation and tracking.

- [ ] 4.7.1.1 Implement `ElixirCoder.Training.Metrics.compute/2`
- [ ] 4.7.1.2 Compute per-task losses
- [ ] 4.7.1.3 Compute accuracy for classification tasks
- [ ] 4.7.1.4 Compute tokens/sec throughput

### 4.7.2 Logger Callback

- [ ] **Task 4.7.2 Complete**

Implement Axon.Loop callback for logging.

- [ ] 4.7.2.1 Implement `ElixirCoder.Training.Logging.callback/1`
- [ ] 4.7.2.2 Log every N steps (default 100)
- [ ] 4.7.2.3 Log: step, epoch, loss, lr, throughput
- [ ] 4.7.2.4 Format for readability (tables, progress bars)

### 4.7.3 TensorBoard Integration

- [ ] **Task 4.7.3 Complete**

Implement TensorBoard event writing.

- [ ] 4.7.3.1 Implement `ElixirCoder.Training.Logging.TensorBoard.new/1`
- [ ] 4.7.3.2 Write scalar events (loss, metrics)
- [ ] 4.7.3.3 Write histogram events (gradients, weights)
- [ ] 4.7.3.4 Create log directory: `data/logs/run-{timestamp}`

### 4.7.4 Progress Monitoring

- [ ] **Task 4.7.4 Complete**

Implement training progress monitoring.

- [ ] 4.7.4.1 Implement `ElixirCoder.Training.Monitor.start_link/1`
- [ ] 4.7.4.2 GenServer tracking training state
- [ ] 4.7.4.3 Expose metrics via `:telemetry`
- [ ] 4.7.4.4 Support external monitoring tools

### 4.7.5 Unit Tests

- [ ] **Task 4.7.5 Complete**

- [ ] Test metrics compute correctly
- [ ] Test logger callback produces output
- [ ] Test TensorBoard writes valid files
- [ ] Test telemetry events are emitted

---

## 4.8 Curriculum Learning

- [ ] **Section 4.8 Complete**

This section implements curriculum learning, gradually introducing training complexity.

### 4.8.1 Phase Definition

- [ ] **Task 4.8.1 Complete**

Define curriculum phases.

- [ ] 4.8.1.1 Create `ElixirCoder.Training.Curriculum.Phase` struct
- [ ] 4.8.1.2 Define Phase 1: epochs 1-10, code-only MLM
- [ ] 4.8.1.3 Define Phase 2: epochs 11-30, code + simple ontology
- [ ] 4.8.1.4 Define Phase 3: epochs 31-50, code + full ontology
- [ ] 4.8.1.5 Define Phase 4: epochs 51+, all tasks

### 4.8.2 Phase Transitions

- [ ] **Task 4.8.2 Complete**

Implement automatic phase transitions.

- [ ] 4.8.2.1 Implement `ElixirCoder.Training.Curriculum.current_phase/2`
- [ ] 4.8.2.2 Determine phase from current epoch
- [ ] 4.8.2.3 Return phase configuration
- [ ] 4.8.2.4 Log phase transitions

### 4.8.3 Active Task Selection

- [ ] **Task 4.8.3 Complete**

Implement task activation based on phase.

- [ ] 4.8.3.1 Implement `ElixirCoder.Training.Curriculum.active_tasks/1`
- [ ] 4.8.3.2 Phase 1: only code_generation
- [ ] 4.8.3.3 Phase 2: + ontology annotation tasks
- [ ] 4.8.3.4 Phase 3: + test_generation
- [ ] 4.8.3.5 Phase 4: all tasks active

### 4.8.4 Loss Weight Adjustment

- [ ] **Task 4.8.4 Complete**

Implement dynamic loss weights per phase.

- [ ] 4.8.4.1 Implement `ElixirCoder.Training.Curriculum.loss_weights/2`
- [ ] 4.8.4.2 Scale newly introduced tasks from 0.1 → 1.0 over 5 epochs
- [ ] 4.8.4.3 Keep established tasks at full weight
- [ ] 4.8.4.4 Return weight map for current phase

### 4.8.5 Curriculum Callback

- [ ] **Task 4.8.5 Complete**

Implement Axon.Loop callback for curriculum.

- [ ] 4.8.5.1 Implement `ElixirCoder.Training.Curriculum.callback/1`
- [ ] 4.8.5.2 Check phase at epoch boundary
- [ ] 4.8.5.3 Update active tasks and weights
- [ ] 4.8.5.4 Log transition events

### 4.8.6 Unit Tests

- [ ] **Task 4.8.6 Complete**

- [ ] Test phase selection based on epoch
- [ ] Test active tasks match phase definition
- [ ] Test loss weights scale correctly
- [ ] Test callback triggers transitions

---

## Success Criteria

1. **Data Pipeline**: Sustains >1000 samples/sec throughput
2. **Training Loop**: Completes one epoch without errors
3. **Loss Computation**: Multi-task loss produces valid gradients
4. **Checkpointing**: Save/load preserves model state
5. **Monitoring**: Metrics logged correctly

## Provides Foundation

This phase establishes the infrastructure for:
- **Phase 5**: Actual multi-task training execution
- **Phase 6**: Model deployment from checkpoints
- **Phase 7**: Evaluation using trained models
