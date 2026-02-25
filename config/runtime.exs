import Config

# Runtime configuration (evaluated at boot time)
if config_env() == :prod do
  # In production, read from environment variable
  elixir_ontologies_path =
    System.get_env("ELIXIR_ONTOLOGIES_PATH") ||
      Path.expand("~/code/elixir_ontologies")

  config :elixir_coder, elixir_ontologies_path: elixir_ontologies_path

  requested_backend =
    case System.get_env("ELIXIR_CODER_BACKEND") do
      "custom" -> :custom
      "edifice" -> :edifice
      _ -> :edifice
    end

  allow_fallback? =
    case String.downcase(System.get_env("ELIXIR_CODER_BACKEND_ALLOW_FALLBACK") || "true") do
      "0" -> false
      "false" -> false
      _ -> true
    end

  config :elixir_coder, ElixirCoder.Backend.Runtime,
    requested_backend: requested_backend,
    allow_fallback?: allow_fallback?
end
