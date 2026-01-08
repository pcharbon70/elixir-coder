# Research-to-Planning Gap Analysis

This document identifies gaps between research findings (in `notes/research/`) and planning documents (in `notes/planning/`), with recommendations for which gaps must be addressed in Phases 1-5 versus those that can defer to Phase 6+ or future work.

---

## Executive Summary

| Category | Missing from Planning | Priority | Phase |
|----------|----------------------|----------|-------|
| **Rich semantic extraction** | Full pipeline for guards, patterns, @spec | Critical | 1 |
| **Contrastive learning** | Clean/violating code pair generation | High | 4-5 |
| **Instructional content** | 70/20/10 training mix strategy | High | 5 |
| **Security ontology** | SHACL shapes, CWE mappings | High | 1 |
| **Evaluation benchmarks** | ElixirEval benchmark suite | High | 7 |
| **Clarification** | Largely covered | - | - |
| **Muzak RL** | Execution feedback loop | Medium | 5 |
| **LoRA adaptation** | Lorax for test specialization | Defer | 6+ |

---

## Detailed Gap Analysis

### 1. Rich Semantic Extraction (Research 1.06)

**Research Finding**: Pre-generated .ttl files contain only module/function identity. Full elixir-ontologies pipeline extracts guards, pattern parameters, @spec, @callback definitions—critical for training quality.

**Planning Coverage**:
- ✅ Phase 1.0.3 loads pre-generated .ttl files
- ❌ **MISSING**: Running full pipeline on downloaded source code
- ❌ **MISSING**: Extracting guards, patterns, @spec, @callback

**Impact**: Without rich semantic extraction, model misses:
- Guard expressions (25% of clauses)
- Type specifications (40% of functions)
- Pattern parameters (60% of parameters)

**Recommendation**: **Add to Phase 1** as Section 1.2.8 "Rich Semantic Extraction"

```
- [ ] 1.2.8.1 Implement `ElixirCoder.Data.Ontology.extract_rich/1`
- [ ] 1.2.8.2 Use `ElixirOntologies.Pipeline.analyze_and_build/2`
- [ ] 1.2.8.3 Extract guard clauses with combinator logic
- [ ] 1.2.8.4 Extract pattern parameters (tuple, map, struct, binary)
- [ ] 1.2.8.5 Extract @spec type specifications
- [ ] 1.2.8.6 Extract @callback definitions
- [ ] 1.2.8.7 Store enriched JSON: `data/processed/enriched/{package}.json`
- [ ] 1.2.8.8 Include full RDF graph in quad store
```

**Can Defer?**: No. This is core to the ontology-augmented approach and must be done during data preparation.

---

### 2. Contrastive Learning (Research 1.02)

**Research Finding**: Contrastive pre-training (InfoNCE loss on clean/violating pairs) significantly improves quality awareness. ContraCode framework shows pulling clean code away from violating variants in embedding space.

**Planning Coverage**:
- ✅ Phase 5.3 mentions Credo classification
- ❌ **MISSING**: Generating contrastive training pairs
- ❌ **MISSING**: InfoNCE loss implementation
- ❌ **MISSING**: Curriculum by rule complexity

**Impact**: Without contrastive learning, model may not internalize quality distinctions as effectively.

**Recommendation**: **Add to Phase 4** as Section 4.3 "Contrastive Learning Infrastructure"

```
- [ ] 4.3.1 Implement `ElixirCoder.Training.Contrastive.generate_pairs/2`
- [ ] 4.3.2 Generate clean/violating pairs for each Credo rule
- [ ] 4.3.3 Implement InfoNCE loss in Axon
- [ ] 4.3.4 Curriculum ordering: surface → structural → corpus-level rules
- [ ] 4.3.5 Balance contrastive loss with primary objectives
```

**Can Defer?**: Yes, to Phase 6+ or post-deployment improvement. The model will still function without it, just with lower quality awareness.

---

### 3. Instructional Content Mix (Research 1.06)

**Research Finding**: 70/20/10 split (source/docs/tutorials) preserves production code quality while enabling conversational capabilities. Lower learning rate (1e-5) for instruction phase.

**Planning Coverage**:
- ✅ Phase 5.9.1 added training data mix strategy (recently added)
- ✅ Phase 5.9.2 added official docs extraction (recently added)
- ⚠️ Partial: Implementation tasks defined but not integrated with Phase 5.1-5.8

**Impact**: Recent additions addressed this gap.

**Recommendation**: None needed—already added to planning.

---

### 4. Security Ontology Integration (Research 1.03)

**Research Finding**: SHACL shapes encode Sobelow rules as formal constraints. CWE mappings enable semantic interoperability. Security ontology extends elixir-core.ttl with vulnerability classes.

**Planning Coverage**:
- ✅ Phase 1.5 mentions Sobelow annotation
- ❌ **MISSING**: Security ontology definitions (SHACL shapes)
- ❌ **MISSING**: CWE mappings for each Sobelow check
- ❌ **MISSING**: Security vulnerability classes in ontology

**Impact**: Security head will work but lacks formal grounding in ontology.

**Recommendation**: **Add to Phase 1** as Section 1.6 "Security Ontology Extension"

```
- [ ] 1.6.1 Define security ontology extension
- [ ] 1.6.2 Map Sobelow checks to CWE identifiers
- [ ] 1.6.3 Create SHACL shapes for security constraints
- [ ] 1.6.4 Load security ontology into `graph:ontology/security`
- [ ] 1.6.5 Test SPARQL queries for vulnerability patterns
```

**Can Defer?**: Yes, to Phase 6+. Security detection will work via training labels; formal ontology is enhancement.

---

### 5. ElixirEval Benchmark Suite (Research 1.01)

**Research Finding**: No Elixir-specific code generation benchmark exists. Should build HumanEval/MBPP-style suite with OTP extensions: function-level, OTP patterns, Phoenix components, semantic probes, ontology-specific tests.

**Planning Coverage**:
- ✅ Phase 7.2 mentions evaluation benchmarks
- ❌ **MISSING**: ElixirEval problem set creation
- ❌ **MISSING**: OTP-specific test cases
- ❌ **MISSING**: Semantic probing tasks (pattern matching, pipes, process communication)

**Impact**: Without dedicated benchmark, evaluation will rely on generic metrics or manual assessment.

**Recommendation**: **Add to Phase 7** as Section 7.2.1 "ElixirEval Benchmark"

```
- [ ] 7.2.1.1 Create 100+ function-level problems
- [ ] 7.2.1.2 Create 50+ OTP-specific problems (GenServer, Supervisor)
- [ ] 7.2.1.3 Create 30+ Phoenix web component problems
- [ ] 7.2.1.4 Create semantic probing tasks
- [ ] 7.2.1.5 Establish pass@k metrics
- [ ] 7.2.1.6 CodeBLEU evaluation infrastructure
```

**Can Defer?**: Evaluation naturally occurs in Phase 7. This is the right phase.

---

### 6. Clarification System (Research 1.04)

**Research Finding**: Multi-sample divergence detection, semantic entropy for uncertainty, EVPI-based question ranking, single-round paradigm.

**Planning Coverage**:
- ✅ Phase 5.4 covers clarification detection
- ✅ Phase 5.5 covers question generation
- ✅ Phase 6.1 covers ambiguity detection
- ✅ Phase 5.4.4 mentions semantic entropy
- ⚠️ **MINOR**: EVPI ranking not explicitly mentioned

**Impact**: Well covered in planning.

**Recommendation**: Add EVPI (Expected Value of Perfect Information) ranking to Phase 5.5.2:

```
- [ ] 5.5.2.4 Implement EVPI-based question ranking
- [ ] 5.5.2.5 Score questions by expected information gain
```

**Can Defer?**: This is a refinement, not a gap. Can add in Phase 5 implementation.

---

### 7. Muzak Execution Feedback (Research 1.05)

**Research Finding**: Mutation testing provides execution-grounded rewards. CodeRL-style policy gradient with mutation scores.

**Planning Coverage**:
- ✅ Phase 5.6 mentions test generation
- ❌ **MISSING**: Muzak reward computation
- ❌ **MISSING**: RL fine-tuning with mutation feedback
- ❌ **MISSING**: Aggressive caching for expensive Muzak runs

**Impact**: Test generation will work but won't have execution quality signal during training.

**Recommendation**: **Add to Phase 5** as Section 5.6.5 "Execution Feedback with Muzak"

```
- [ ] 5.6.5.1 Implement `ElixirCoder.Testing.Muzak.reward/2`
- [ ] 5.6.5.2 Parse mutation scores from Muzak output
- [ ] 5.6.5.3 Implement policy gradient RL loop
- [ ] 5.6.5.4 Cache mutation results by content hash
- [ ] 5.6.5.5 Sample mutations during early training
```

**Can Defer?**: Yes, to Phase 6+. Test generation can use supervised learning initially; RL is enhancement.

---

### 8. LoRA Adaptation (Research 1.05)

**Research Finding**: Lorax enables efficient test-type specialization (ExUnit, StreamData, LiveViewTest) without full model retraining. Hot-swappable adapters.

**Planning Coverage**:
- ❌ **MISSING**: No mention of LoRA or Lorax
- ❌ **MISSING**: Test-type specialization architecture

**Impact**: Single model for all test types; less flexibility for deployment.

**Recommendation**: **Defer to Phase 6+** as future work:

```
Phase 6+ Future Work:
- [ ] 6+.1 Integrate Lorax for LoRA adaptation
- [ ] 6+.2 Create ExUnit-specific adapter
- [ ] 6+.3 Create StreamData-specific adapter
- [ ] 6+.4 Create LiveViewTest-specific adapter
- [ ] 6+.5 Implement hot-swap serving
```

**Can Defer?**: Yes. Base model will work fine; LoRA is optimization for specialized deployment.

---

### 9. Credo Multi-Task Architecture (Research 1.02)

**Research Finding**: Shared encoder with three heads (generation, classification, explanation). Uncertainty weighting for loss balancing.

**Planning Coverage**:
- ✅ Phase 5.3 covers Credo classification
- ✅ Phase 5.7 covers explanation generation
- ⚠️ **MINOR**: Uncertainty weighting not mentioned

**Impact**: Mostly covered.

**Recommendation**: Add uncertainty weighting (Kendall et al.) to Phase 4.2:

```
- [ ] 4.2.4 Implement uncertainty-based loss weighting
- [ ] 4.2.5 Use GradNorm for gradient magnitude balancing
```

**Can Defer?**: This is optimization; base multi-task will work.

---

### 10. Hybrid Python/Elixir Approach (Research 1.01)

**Research Finding**: Python for graph preprocessing (pyRDF2Vec, OWL2Vec*) + Elixir for training/inference. Axon has limitations for GNN operations.

**Planning Coverage**:
- ❌ **MISSING**: No Python pipeline components
- ❌ **MISSING**: Graph embedding export/import

**Impact**: May need custom GNN implementation in Elixir or accept linearized-only approach.

**Recommendation**: **Add to Phase 3** as Section 3.5 "Optional: Graph Preprocessing with Python"

```
- [ ] 3.5.1 (Optional) Set up Python environment for graph tools
- [ ] 3.5.2 (Optional) pyRDF2Vec embedding generation
- [ ] 3.5.3 (Optional) Export embeddings for Elixir import
- [ ] 3.5.4 (Optional) Hybrid training pipeline
```

**Can Defer?**: Yes. Linearized approach (already planned) will work; Python preprocessing is optimization.

---

## Summary Table

| Gap | Priority | Add to Phase | Can Defer? |
|-----|----------|--------------|------------|
| Rich semantic extraction (guards, @spec, patterns) | **Critical** | Phase 1.2.8 | No |
| Security ontology (SHACL, CWE) | High | Phase 1.6 | Yes (Phase 6+) |
| Contrastive learning (InfoNCE loss) | High | Phase 4.3 | Yes (Phase 6+) |
| ElixirEval benchmark | High | Phase 7.2.1 | No (Phase 7 is right time) |
| Muzak execution feedback | Medium | Phase 5.6.5 | Yes (Phase 6+) |
| EVPI question ranking | Low | Phase 5.5.2 | Yes (refinement) |
| LoRA adaptation | Low | Phase 6+ | Yes |
| Uncertainty weighting | Low | Phase 4.2.4 | Yes |
| Python hybrid pipeline | Low | Phase 3.5 | Yes |

---

## Recommended Planning Updates

### Must Add to Phases 1-5

1. **Phase 1.2.8**: Rich Semantic Extraction
   - Use full elixir-ontologies pipeline
   - Extract guards, patterns, @spec, @callback

2. **Phase 1.6**: Security Ontology Extension (optional for Phase 1-5)
   - SHACL shapes for Sobelow rules
   - CWE mappings

3. **Phase 4.3**: Contrastive Learning Infrastructure (optional)
   - InfoNCE loss for clean/violating pairs
   - Curriculum by rule complexity

4. **Phase 5.6.5**: Muzak Execution Feedback (optional)
   - Mutation score rewards
   - RL fine-tuning

5. **Phase 7.2.1**: ElixirEval Benchmark
   - 100+ function problems
   - OTP-specific tests
   - Semantic probes

### Can Defer to Phase 6+ or Future Work

1. LoRA/Lorax adaptation for test specialization
2. Python hybrid pipeline for graph preprocessing
3. Full security ontology (training labels work initially)

---

## Implementation Priority

If resources are limited, implement in this order:

1. **Rich semantic extraction** - Core to ontology approach
2. **ElixirEval benchmark** - Essential for evaluation
3. **Contrastive learning** - Significant quality improvement
4. **Muzak feedback** - Enhances test generation
5. **Security ontology** - Formal enhancement
6. **LoRA adaptation** - Deployment optimization
7. **Python pipeline** - Optional optimization

---

## Conclusion

The planning documents are comprehensive and well-aligned with research. The main gap is **rich semantic extraction** using the full elixir-ontologies pipeline—this should be added to Phase 1 as it's fundamental to the ontology-augmented approach.

Most other gaps are enhancements that can defer to later phases without compromising core functionality. The research-to-planning alignment is strong overall.
