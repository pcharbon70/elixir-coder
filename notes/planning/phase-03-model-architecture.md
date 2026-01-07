# Phase 3: Model Architecture

## Overview

Phase 3 implements the core transformer model architecture in Axon. By the end of this phase, we will have a functional encoder-decoder transformer with multi-head self-attention, feed-forward layers, and support for the multiple task heads required for multi-task learning.

The design follows the CodeT5 architecture, which has proven effective for code understanding and generation tasks. We implement the model in pure Elixir using Axon, leveraging EXLA for GPU acceleration. The architecture supports 125M-350M parameter configurations, allowing us to scale based on training results.

This phase establishes the foundational model that will be trained in Phase 4 and Phase 5, with architecture decisions informed by the tokenization and data preparation work from previous phases.

---

## 3.1 Architecture Design

- [ ] **Section 3.1 Complete**

This section defines the overall model architecture, including layer counts, hidden sizes, and parameter targets for different model sizes.

We provide two configurations: a 125M parameter base model for fast iteration and development, and a 350M parameter full model for production deployment.

### 3.1.1 Model Configuration

- [ ] **Task 3.1.1 Complete**

Define model configurations for different sizes.

- [ ] 3.1.1.1 Create `ElixirCoder.Model.Config` struct
- [ ] 3.1.1.2 Define `base/0` config: 125M params, 12 layers, 768 hidden, 12 heads
- [ ] 3.1.1.3 Define `full/0` config: 350M params, 24 layers, 1024 hidden, 16 heads
- [ ] 3.1.1.4 Define `vocab_size: 32000`, `max_seq_len: 4096`, `dropout: 0.1`
- [ ] 3.1.1.5 Define `hidden_ffn_multiplier: 4` (3072 for base, 4096 for full)

### 3.1.2 Encoder-Decoder Structure

- [ ] **Task 3.1.2 Complete**

Define the encoder-decoder architecture pattern.

- [ ] 3.1.2.1 Document encoder role: bidirectional encoding of input
- [ ] 3.1.2.2 Document decoder role: autoregressive generation with cross-attention
- [ ] 3.1.2.3 Compare to decoder-only: better for code-to-test translation
- [ ] 3.1.2.4 Reference Bumblebee implementations for patterns

### 3.1.3 Layer Count Justification

- [ ] **Task 3.1.3 Complete**

Document layer count selection based on research.

- [ ] 3.1.3.1 Research CodeT5, CodeParrot, StarCoder architectures
- [ ] 3.1.3.2 Create `notes/architecture/layer-analysis.md`
- [ ] 3.1.3.3 Justify 12 layers for base (similar to GPT-2 Small)
- [ ] 3.1.3.4 Justify 24 layers for full (similar to CodeT5-Base)

### 3.1.4 Parameter Verification

- [ ] **Task 3.1.4 Complete**

Implement parameter counting for architecture validation.

- [ ] 3.1.4.1 Implement `ElixirCoder.Model.Architecture.count_parameters/1`
- [ ] 3.1.4.2 Compute embedding params: vocab_size * hidden_size
- [ ] 3.1.4.3 Compute transformer params per layer
- [ ] 3.1.4.4 Verify base config ~125M, full config ~350M

### 3.1.5 Unit Tests

- [ ] **Task 3.1.5 Complete**

- [ ] Test config structs have correct values
- [ ] Test parameter counts match targets
- [ ] Test layer counts are consistent with research

---

## 3.2 Embedding Layer

- [ ] **Section 3.2 Complete**

This section implements the embedding layer that converts token IDs to dense vector representations, combining token embeddings with positional encodings.

### 3.2.1 Token Embeddings

- [ ] **Task 3.2.1 Complete**

Implement token embedding lookup.

- [ ] 3.2.1.1 Implement `ElixirCoder.Model.Embeddings.token_embedding/2`
- [ ] 3.2.1.2 Use `Axon.embedding(vocab_size, hidden_size)`
- [ ] 3.2.1.3 Initialize with normal distribution (std=0.02)
- [ ] 3.2.1.4 Support tying encoder/decoder embeddings (share weights)

### 3.2.2 Positional Encodings

- [ ] **Task 3.2.2 Complete**

Implement sinusoidal positional encodings.

- [ ] 3.2.2.1 Implement `ElixirCoder.Model.Embeddings.positional_encoding/2`
- [ ] 3.2.2.2 Use sin/cos formulation from Vaswani et al.
- [ ] 3.2.2.3 Support max sequence length of 4096
- [ ] 3.2.2.4 Implement as Axon layer (not precomputed, but computed)

### 3.2.3 Embedding Combination

- [ ] **Task 3.2.3 Complete**

Combine token and positional embeddings.

- [ ] 3.2.3.1 Implement `ElixirCoder.Model.Embeddings.combine/3`
- [ ] 3.2.3.2 Add token embeddings + positional encodings
- [ ] 3.2.3.3 Apply layer normalization
- [ ] 3.2.3.4 Apply dropout (training only)

### 3.2.4 Position Embedding Alternative

- [ ] **Task 3.2.4 Complete**

Implement learned position embeddings (alternative to sinusoidal).

- [ ] 3.2.4.1 Implement `ElixirCoder.Model.Embeddings.learned_positions/2`
- [ ] 3.2.4.2 Use `Axon.embedding(max_seq_len, hidden_size)`
- [ ] 3.2.4.3 Allow config to choose between sinusoidal and learned
- [ ] 3.2.4.4 Default to sinusoidal for base, learned for full

### 3.2.5 Unit Tests

- [ ] **Task 3.2.5 Complete**

- [ ] Test token embedding produces correct shape
- [ ] Test positional encoding varies by position
- [ ] Test combination produces correct output
- [ ] Test dropout disabled during inference

---

## 3.3 Multi-Head Attention

- [ ] **Section 3.3 Complete**

This section implements multi-head self-attention, the core mechanism that enables transformers to model relationships between all positions in a sequence.

### 3.3.1 Scaled Dot-Product Attention

- [ ] **Task 3.3.1 Complete**

Implement scaled dot-product attention in Nx.Defn.

- [ ] 3.3.1.1 Implement `ElixirCoder.Model.Attention.scaled_dot_product_attention/4`
- [ ] 3.3.1.2 Compute scores: Q @ K^T / sqrt(d_k)
- [ ] 3.3.1.3 Apply softmax to get attention weights
- [ ] 3.3.1.4 Apply weights to V: weights @ V
- [ ] 3.3.1.5 Support causal masking for decoder

### 3.3.2 Multi-Head Projection

- [ ] **Task 3.3.2 Complete**

Implement Q, K, V projections for multiple heads.

- [ ] 3.3.2.1 Implement `ElixirCoder.Model.Attention.multi_head_projection/4`
- [ ] 3.3.2.2 Project input to Q, K, V separately
- [ ] 3.3.2.3 Split into num_heads heads
- [ ] 3.3.2.4 Reshape to [batch, heads, seq, head_dim]

### 3.3.3 Attention Output Projection

- [ ] **Task 3.3.3 Complete**

Implement output projection and residual connection.

- [ ] 3.3.3.1 Implement `ElixirCoder.Model.Attention.output_projection/3`
- [ ] 3.3.3.2 Concatenate heads
- [ ] 3.3.3.3 Project back to hidden_size
- [ ] 3.3.3.4 Add residual connection and layer norm

### 3.3.4 Axon Layer Integration

- [ ] **Task 3.3.4 Complete**

Wrap attention functions as Axon layers.

- [ ] 3.3.4.1 Implement `ElixirCoder.Model.Attention.layer/4`
- [ ] 3.3.4.2 Use `Axon.layer` to wrap Defn functions
- [ ] 3.3.4.3 Support `name:` parameter for layer identification
- [ ] 3.3.4.4 Handle both self-attention and cross-attention

### 3.3.5 Causal Masking

- [ ] **Task 3.3.5 Complete**

Implement causal masking for autoregressive decoding.

- [ ] 3.3.5.1 Implement `ElixirCoder.Model.Attention.causal_mask/2`
- [ ] 3.3.5.2 Create lower-triangular mask for sequence length
- [ ] 3.3.5.3 Apply mask to attention scores (set future to -inf)
- [ ] 3.3.5.4 Support key/value cache for efficient generation

### 3.3.6 Unit Tests

- [ ] **Task 3.3.6 Complete**

- [ ] Test scaled dot-product attention produces correct output
- [ ] Test multi-head projection splits correctly
- [ ] Test causal masking prevents future attention
- [ ] Test key/value cache produces identical results

---

## 3.4 Feed-Forward Network

- [ ] **Section 3.4 Complete**

This section implements the position-wise feed-forward network that follows each attention layer, providing non-linear transformation capacity.

### 3.4.1 FFN Layer

- [ ] **Task 3.4.1 Complete**

Implement the feed-forward network.

- [ ] 3.4.1.1 Implement `ElixirCoder.Model.FFN.layer/3`
- [ ] 3.4.1.2 Project to ffn_dim (hidden_size * 4)
- [ ] 3.4.1.3 Apply GELU activation
- [ ] 3.4.1.4 Project back to hidden_size
- [ ] 3.4.1.5 Add residual connection and layer norm

### 3.4.2 Activation Functions

- [ ] **Task 3.4.2 Complete**

Implement activation function options.

- [ ] 3.4.2.1 Implement GELU (Gaussian Error Linear Unit)
- [ ] 3.4.2.2 Implement ReLU alternative (for ablation)
- [ ] 3.4.2.3 Implement Swish alternative (for experimentation)
- [ ] 3.4.2.4 Default to GELU (proven for transformers)

### 3.4.3 Unit Tests

- [ ] **Task 3.4.3 Complete**

- [ ] Test FFN layer produces correct output shape
- [ ] Test GELU activation approximates expected values
- [ ] Test residual connection preserves gradient flow

---

## 3.5 Transformer Blocks

- [ ] **Section 3.5 Complete**

This section combines attention and FFN into complete transformer blocks for both encoder and decoder.

### 3.5.1 Encoder Block

- [ ] **Task 3.5.1 Complete**

Implement the encoder transformer block.

- [ ] 3.5.1.1 Implement `ElixirCoder.Model.Encoder.block/3`
- [ ] 3.5.1.2 Multi-head self-attention with residual
- [ ] 3.5.1.3 Feed-forward network with residual
- [ ] 3.5.1.4 Two layer normalizations (pre-norm or post-norm)
- [ ] 3.5.1.5 Dropout after each sub-layer

### 3.5.2 Decoder Block

- [ ] **Task 3.5.2 Complete**

Implement the decoder transformer block.

- [ ] 3.5.2.1 Implement `ElixirCoder.Model.Decoder.block/4`
- [ ] 3.5.2.2 Masked multi-head self-attention (causal)
- [ ] 3.5.2.3 Cross-attention to encoder outputs
- [ ] 3.5.2.4 Feed-forward network
- [ ] 3.5.2.5 Three residual connections with layer norms

### 3.5.3 Stack Construction

- [ ] **Task 3.5.3 Complete**

Implement stacking of multiple transformer blocks.

- [ ] 3.5.3.1 Implement `ElixirCoder.Model.Encoder.stack/3`
- [ ] 3.5.3.2 Implement `ElixirCoder.Decoder.stack/4`
- [ ] 3.5.3.3 Support variable layer counts via config
- [ ] 3.5.3.4 Name layers consistently (e.g., "encoder_layer_0", "encoder_layer_1")

### 3.5.4 Unit Tests

- [ ] **Task 3.5.4 Complete**

- [ ] Test encoder block processes input correctly
- [ ] Test decoder block attends to encoder output
- [ ] Test stack produces correct layer count
- [ ] Test gradient flows through all layers

---

## 3.6 Encoder-Decoder Model

- [ ] **Section 3.6 Complete**

This section assembles the complete encoder-decoder transformer model.

### 3.6.1 Encoder Assembly

- [ ] **Task 3.6.1 Complete**

Assemble the complete encoder from components.

- [ ] 3.6.1.1 Implement `ElixirCoder.Model.Encoder.build/2`
- [ ] 3.6.1.2 Input: token ids, shape: {batch, seq_len}
- [ ] 3.6.1.3 Embedding layer (token + position)
- [ ] 3.6.1.4 Stack of encoder blocks
- [ ] 3.6.1.5 Output: encoded representations

### 3.6.2 Decoder Assembly

- [ ] **Task 3.6.2 Complete**

Assemble the complete decoder from components.

- [ ] 3.6.2.1 Implement `ElixirCoder.Model.Decoder.build/3`
- [ ] 3.6.2.2 Inputs: decoder ids, encoder outputs
- [ ] 3.6.2.3 Embedding layer (token + position)
- [ ] 3.6.2.4 Stack of decoder blocks with cross-attention
- [ ] 3.6.2.5 Output: decoder representations

### 3.6.3 Model Assembly

- [ ] **Task 3.6.3 Complete**

Assemble the complete encoder-decoder model.

- [ ] 3.6.3.1 Implement `ElixirCoder.Model.build/2`
- [ ] 3.6.3.2 Connect encoder and decoder
- [ ] 3.6.3.3 Final output projection to vocab_size
- [ ] 3.6.3.4 Return Axon struct ready for training

### 3.6.4 Forward Pass Verification

- [ ] **Task 3.6.4 Complete**

Implement and test forward pass.

- [ ] 3.6.4.1 Implement `ElixirCoder.Model.forward/3`
- [ ] 3.6.4.2 Accept inputs, encoder_ids, decoder_ids
- [ ] 3.6.4.3 Return logits of shape {batch, seq_len, vocab_size}
- [ ] 3.6.4.4 Verify with dummy input: produces valid output

### 3.6.5 Unit Tests

- [ ] **Task 3.6.5 Complete**

- [ ] Test encoder builds correctly
- [ ] Test decoder builds correctly
- [ ] Test full model forward pass
- [ ] Test output shapes match expectations

---

## 3.7 Task Heads

- [ ] **Section 3.7 Complete**

This section implements the task-specific heads for multi-task learning, building on the shared encoder-decoder backbone.

### 3.7.1 Code Generation Head

- [ ] **Task 3.7.1 Complete**

Implement the code generation head (language modeling).

- [ ] 3.7.1.1 Implement `ElixirCoder.Model.Heads.code_generation/2`
- [ ] 3.7.1.2 Linear layer to vocab_size
- [ ] 3.7.1.3 Softmax for token probabilities
- [ ] 3.7.1.4 Support both encoder-only and encoder-decoder modes

### 3.7.2 Quality Classification Head

- [ ] **Task 3.7.2 Complete**

Implement the Credo quality classification head.

- [ ] 3.7.2.1 Implement `ElixirCoder.Model.Heads.quality_classification/2`
- [ ] 3.7.2.2 Global average pooling over sequence
- [ ] 3.7.2.3 Linear layer to num_quality_labels (83+ Credo checks)
- [ ] 3.7.2.4 Sigmoid activation for multi-label classification

### 3.7.3 Security Classification Head

- [ ] **Task 3.7.3 Complete**

Implement the Sobelow security classification head.

- [ ] 3.7.3.1 Implement `ElixirCoder.Model.Heads.security_classification/2`
- [ ] 3.7.3.2 Global average pooling over sequence
- [ ] 3.7.3.3 Linear layer to num_security_labels (30+ vulnerability types)
- [ ] 3.7.3.4 Sigmoid activation for multi-label classification

### 3.7.4 Test Generation Head

- [ ] **Task 3.7.4 Complete**

Implement the test generation head.

- [ ] 3.7.4.1 Implement `ElixirCoder.Model.Heads.test_generation/2`
- [ ] 3.7.4.2 Separate decoder (or shared with code gen)
- [ ] 3.7.4.3 Output to vocab_size
- [ ] 3.7.4.4 Support bidirectional (code→test, test→code)

### 3.7.5 Clarification Head

- [ ] **Task 3.7.5 Complete**

Implement the clarification (ask vs. proceed) detection head.

- [ ] 3.7.5.1 Implement `ElixirCoder.Model.Heads.clarification_detection/2`
- [ ] 3.7.5.2 Binary classification: ask or proceed
- [ ] 3.7.5.3 Global pooling + linear to 1 output
- [ ] 3.7.5.4 Sigmoid activation for probability

### 3.7.6 Question Generation Head

- [ ] **Task 3.7.6 Complete**

Implement the clarification question generation head.

- [ ] 3.7.6.1 Implement `ElixirCoder.Model.Heads.question_generation/2`
- [ ] 3.7.6.2 Decoder for text generation
- [ ] 3.7.6.3 Output to vocab_size
- [ ] 3.7.6.4 Special tokens for question framing

### 3.7.7 Explanation Head

- [ ] **Task 3.7.7 Complete**

Implement the explanation generation head.

- [ ] 3.7.7.1 Implement `ElixirCoder.Model.Heads.explanation_generation/2`
- [ ] 3.7.7.2 Decoder for natural language
- [ ] 3.7.7.3 Output to vocab_size
- [ ] 3.7.7.4 Chain-of-thought prompting integration

### 3.7.8 Multi-Task Model Assembly

- [ ] **Task 3.7.8 Complete**

Assemble the complete multi-task model.

- [ ] 3.7.8.1 Implement `ElixirCoder.Model.MultiTask.build/2`
- [ ] 3.7.8.2 Shared encoder-decoder backbone
- [ ] 3.7.8.3 All task heads attached
- [ ] 3.7.8.4 Return container of outputs for joint training

### 3.7.9 Unit Tests

- [ ] **Task 3.7.9 Complete**

- [ ] Test code generation head produces valid logits
- [ ] Test quality head produces multi-label outputs
- [ ] Test security head produces multi-label outputs
- [ ] Test clarification head produces binary output
- [ ] Test multi-task model produces all outputs

---

## Success Criteria

1. **Model Construction**: Axon model builds without errors
2. **Forward Pass**: Dummy input produces valid output
3. **Parameter Count**: Base config ~125M, full config ~350M
4. **Task Heads**: All 6 heads produce valid outputs
5. **GPU Compatibility**: EXLA compilation succeeds

## Provides Foundation

This phase establishes the model for:
- **Phase 4**: Training pipeline uses model architecture
- **Phase 5**: Multi-task heads enable joint training
- **Phase 6**: Model serves as basis for inference
