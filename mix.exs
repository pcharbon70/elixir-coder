defmodule ElixirCoder.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_coder,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      # Path to local elixir-ontologies repository
      elixir_ontologies_path: Path.expand("~/code/elixir_ontologies")
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets],
      mod: {ElixirCoder.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      setup: ["deps.get", "format --check-formatted"]
    ]
  end

  defp deps do
    [
      # Neural networks
      {:axon, "~> 0.6"},
      {:nx, "~> 0.7"},
      {:exla, "~> 0.7"},
      {:bumblebee, "~> 0.5"},
      {:tokenizers, "~> 0.5"},

      # RDF/OWL processing
      {:rdf, "~> 2.0"},

      # Data processing
      {:req, "~> 0.5"},
      {:floki, "~> 0.36"},
      {:flow, "~> 1.2"},
      {:jason, "~> 1.4"},

      # Code quality & security (dev/test only)
      {:credo, "~> 1.7", only: [:dev, :test]},
      {:sobelow, "~> 0.14", only: [:dev, :test]},

      # Testing
      {:stream_data, "~> 1.1", only: [:test, :dev]},

      # Tooling
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:benchee, "~> 1.3", only: :dev},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
