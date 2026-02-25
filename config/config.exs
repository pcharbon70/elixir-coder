import Config

# Elixir-ontologies path (relative to this project)
config :elixir_coder,
  elixir_ontologies_path: Path.expand("../elixir-ontologies", __DIR__)

config :elixir_coder, ElixirCoder.Backend.Runtime,
  requested_backend: :edifice,
  fallback_backend: :custom,
  allow_fallback?: true,
  required_features: [
    :model_blocks,
    :optimizer,
    :schedule,
    :inference_generation,
    :policy_enforcement
  ]

import_config "#{config_env()}.exs"
