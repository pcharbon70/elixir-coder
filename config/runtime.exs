import Config

# Runtime configuration (evaluated at boot time)
if config_env() == :prod do
  # In production, read from environment variable
  elixir_ontologies_path =
    System.get_env("ELIXIR_ONTOLOGIES_PATH") ||
      Path.expand("~/code/elixir_ontologies")

  config :elixir_coder, elixir_ontologies_path: elixir_ontologies_path
end
