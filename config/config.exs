import Config

# Elixir-ontologies path (can be overridden in environment-specific configs)
config :elixir_coder,
  elixir_ontologies_path: Path.expand("~/code/elixir_ontologies")

import_config "#{config_env()}.exs"
