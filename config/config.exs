import Config

# Elixir-ontologies path (relative to this project)
config :elixir_coder,
  elixir_ontologies_path: Path.expand("../elixir-ontologies", __DIR__)

import_config "#{config_env()}.exs"
