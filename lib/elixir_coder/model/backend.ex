defmodule ElixirCoder.Model.Backend do
  @moduledoc """
  Backend selection helpers for model construction.

  These functions provide Edifice-first selection with a deterministic fallback
  path, while keeping a stable descriptor contract for downstream code.
  """

  alias ElixirCoder.Backend.CapabilityRegistry
  alias ElixirCoder.Backend.Resolver

  @type backend :: CapabilityRegistry.backend()
  @type feature :: CapabilityRegistry.feature()

  @spec capabilities() :: %{backend() => MapSet.t(feature())}
  def capabilities do
    Map.new(CapabilityRegistry.backends(), fn backend ->
      {backend, CapabilityRegistry.capabilities(backend)}
    end)
  end

  @spec build_encoder_decoder(map(), keyword()) ::
          {:ok,
           %{
             backend: backend(),
             builder: module(),
             config: map(),
             fallback?: boolean(),
             requested_backend: backend()
           }}
          | {:error, {:unsupported_features, map()}}
  def build_encoder_decoder(config, opts \\ []) when is_map(config) and is_list(opts) do
    requested_backend = Keyword.get(opts, :backend, :edifice)
    required_features = Keyword.get(opts, :required_features, [:model_blocks])

    with {:ok, selected_backend, metadata} <-
           Resolver.resolve(requested_backend, required_features) do
      {:ok,
       %{
         backend: selected_backend,
         builder: builder_module(selected_backend),
         config: config,
         fallback?: metadata.fallback?,
         requested_backend: requested_backend
       }}
    end
  end

  defp builder_module(:edifice), do: Edifice.Blocks.ModelBuilder
  defp builder_module(:custom), do: ElixirCoder.Model.CustomBuilder
end
