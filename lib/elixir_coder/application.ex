defmodule ElixirCoder.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    elixir_ontologies_path =
      Keyword.get(Mix.Project.config(), :elixir_ontologies_path)
      |> Path.expand()

    children = [
      # Add workers and child processes here
    ]

    opts = [strategy: :one_for_one, name: ElixirCoder.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
