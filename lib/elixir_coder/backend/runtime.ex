defmodule ElixirCoder.Backend.Runtime do
  @moduledoc """
  Runtime backend configuration, resolution, and startup initialization.

  This module centralizes backend defaults and keeps fallback behavior explicit.
  """

  require Logger

  alias ElixirCoder.Backend.CapabilityRegistry
  alias ElixirCoder.Backend.Resolver

  @config_key __MODULE__
  @persistent_key {__MODULE__, :active_resolution}

  @default_requested_backend :edifice
  @default_fallback_backend :custom
  @default_allow_fallback true
  @default_required_features [
    :model_blocks,
    :optimizer,
    :schedule,
    :inference_generation,
    :policy_enforcement
  ]

  @type backend :: CapabilityRegistry.backend()
  @type feature :: CapabilityRegistry.feature()

  @type runtime_config :: %{
          allow_fallback?: boolean(),
          fallback_backend: backend(),
          requested_backend: backend(),
          required_features: [feature()]
        }

  @type resolution :: %{
          backend: backend(),
          capabilities: [feature()],
          config: runtime_config(),
          metadata: Resolver.resolution_metadata()
        }

  @spec config(keyword()) :: runtime_config()
  def config(overrides \\ []) when is_list(overrides) do
    cfg = Application.get_env(:elixir_coder, @config_key, [])

    required_features =
      Keyword.get(
        overrides,
        :required_features,
        Keyword.get(cfg, :required_features, @default_required_features)
      )
      |> List.wrap()
      |> Enum.uniq()

    %{
      allow_fallback?:
        Keyword.get(
          overrides,
          :allow_fallback?,
          Keyword.get(cfg, :allow_fallback?, @default_allow_fallback)
        ),
      fallback_backend:
        Keyword.get(
          overrides,
          :fallback_backend,
          Keyword.get(cfg, :fallback_backend, @default_fallback_backend)
        ),
      requested_backend:
        Keyword.get(
          overrides,
          :requested_backend,
          Keyword.get(cfg, :requested_backend, @default_requested_backend)
        ),
      required_features: required_features
    }
  end

  @spec requested_backend(keyword()) :: backend()
  def requested_backend(overrides \\ []), do: config(overrides).requested_backend

  @spec fallback_backend(keyword()) :: backend()
  def fallback_backend(overrides \\ []), do: config(overrides).fallback_backend

  @spec allow_fallback?(keyword()) :: boolean()
  def allow_fallback?(overrides \\ []), do: config(overrides).allow_fallback?

  @spec resolve(keyword()) ::
          {:ok, resolution()} | {:error, {:unsupported_features, Resolver.unsupported_details()}}
  def resolve(overrides \\ []) when is_list(overrides) do
    runtime_config = config(overrides)

    opts = [
      allow_fallback?: runtime_config.allow_fallback?,
      fallback_backend: runtime_config.fallback_backend
    ]

    case Resolver.resolve(
           runtime_config.requested_backend,
           runtime_config.required_features,
           opts
         ) do
      {:ok, backend, metadata} ->
        {:ok,
         %{
           backend: backend,
           capabilities: CapabilityRegistry.capabilities(backend) |> Enum.sort(),
           config: runtime_config,
           metadata: metadata
         }}

      {:error, {:unsupported_features, _details} = reason} ->
        {:error, reason}
    end
  end

  @spec initialize!(keyword()) :: resolution()
  def initialize!(overrides \\ []) do
    case resolve(overrides) do
      {:ok, resolution} ->
        :persistent_term.put(@persistent_key, resolution)
        log_resolution(resolution)
        resolution

      {:error, {:unsupported_features, details}} ->
        raise ArgumentError, unsupported_error_message(details)
    end
  end

  @spec active_resolution() :: resolution() | nil
  def active_resolution do
    :persistent_term.get(@persistent_key, nil)
  end

  @spec active_backend() :: backend() | nil
  def active_backend do
    case active_resolution() do
      %{backend: backend} -> backend
      _ -> nil
    end
  end

  defp unsupported_error_message(details) do
    """
    backend resolution failed for requested backend #{inspect(details.requested_backend)}.
    missing features: #{inspect(details.missing_features)}.
    fallback backend: #{inspect(details.fallback_backend)}.
    fallback missing features: #{inspect(details.fallback_missing_features)}.
    """
    |> String.trim()
  end

  defp log_resolution(%{backend: backend, config: cfg, metadata: metadata}) do
    base_message =
      "backend=#{backend} requested=#{cfg.requested_backend} " <>
        "fallback_backend=#{cfg.fallback_backend} allow_fallback?=#{cfg.allow_fallback?} " <>
        "required_features=#{inspect(cfg.required_features)}"

    if metadata.fallback? do
      Logger.warning(
        "Backend resolved via fallback: #{base_message} missing=#{inspect(metadata.missing_features)}"
      )
    else
      Logger.info("Backend resolved: #{base_message}")
    end
  end
end
