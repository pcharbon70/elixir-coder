# Edifice Component Map

This document tracks the current Edifice-first mapping for model/backend features.

| Area | Preferred Backend | Fallback Backend | Notes |
|------|-------------------|------------------|-------|
| Shared transformer blocks | `:edifice` | `:custom` | Use Edifice building blocks where tensor contracts match target architecture |
| Optimizer configuration | `:edifice` | `:custom` | Fallback path maps to Polaris/Axon optimizer stack |
| Scheduler configuration | `:edifice` | `:custom` | Keep schedule outputs backend-agnostic |
| PEFT / adapter hooks | `:edifice` | `:custom` | Fallback path may rely on Lorax integration |
| Inference generation | `:edifice` | `:custom` | Selection should be checkpoint-aware and capability-gated |
| Policy enforcement checks | `:edifice` | `:custom` | Behavior must remain consistent across backends |

## Initial Guidance

- Use `ElixirCoder.Backend.CapabilityRegistry` as the source of truth for supported features.
- Use `ElixirCoder.Backend.Resolver` for deterministic selection and fallback behavior.
- Keep response schemas and telemetry labels backend-agnostic so evaluation remains comparable.
