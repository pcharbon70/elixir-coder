[
  profile: :edifice,
  backend: :edifice,
  fallback_backend: :custom,
  allow_fallback?: true,
  required_features: [
    :model_blocks,
    :optimizer,
    :schedule,
    :inference_generation,
    :policy_enforcement
  ],
  seed: 42,
  objective_weights: %{
    code_generation: 1.0,
    quality: 0.5,
    security: 0.5,
    test_generation: 0.8,
    clarification: 0.3,
    explanation: 0.3,
    policy_context: 0.2,
    policy_compliance: 0.2
  }
]
