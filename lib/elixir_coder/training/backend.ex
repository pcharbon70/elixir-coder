defmodule ElixirCoder.Training.Backend do
  @moduledoc """
  Backend adapter entry points for training infrastructure.

  The module returns backend descriptors for optimizer/schedule/PEFT integration
  and keeps backend resolution behavior explicit and testable.
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

  @spec optimizer(map(), keyword()) ::
          {:ok,
           %{
             backend: backend(),
             config: map(),
             fallback?: boolean(),
             provider: :edifice | :polaris
           }}
          | {:error, {:unsupported_features, map()}}
  def optimizer(config, opts \\ []) when is_map(config) do
    with {:ok, selected_backend, metadata} <-
           resolve_backend(opts, [:optimizer]) do
      {:ok,
       %{
         backend: selected_backend,
         config: config,
         fallback?: metadata.fallback?,
         provider: optimizer_provider(selected_backend)
       }}
    end
  end

  @spec schedule(map(), pos_integer(), keyword()) ::
          {:ok,
           %{
             backend: backend(),
             config: map(),
             fallback?: boolean(),
             provider: :edifice | :axon,
             total_steps: pos_integer()
           }}
          | {:error, {:unsupported_features, map()}}
  def schedule(config, total_steps, opts \\ [])
      when is_map(config) and is_integer(total_steps) and total_steps > 0 do
    with {:ok, selected_backend, metadata} <-
           resolve_backend(opts, [:schedule]) do
      {:ok,
       %{
         backend: selected_backend,
         config: config,
         fallback?: metadata.fallback?,
         provider: schedule_provider(selected_backend),
         total_steps: total_steps
       }}
    end
  end

  @spec peft(map(), keyword()) ::
          {:ok,
           %{
             backend: backend(),
             config: map(),
             fallback?: boolean(),
             provider: :edifice | :lorax
           }}
          | {:error, {:unsupported_features, map()}}
  def peft(config, opts \\ []) when is_map(config) do
    with {:ok, selected_backend, metadata} <-
           resolve_backend(opts, [:peft]) do
      {:ok,
       %{
         backend: selected_backend,
         config: config,
         fallback?: metadata.fallback?,
         provider: peft_provider(selected_backend)
       }}
    end
  end

  defp resolve_backend(opts, default_features) do
    requested_backend = Keyword.get(opts, :backend, :edifice)
    required_features = Keyword.get(opts, :required_features, default_features)
    Resolver.resolve(requested_backend, required_features)
  end

  defp optimizer_provider(:edifice), do: :edifice
  defp optimizer_provider(:custom), do: :polaris

  defp schedule_provider(:edifice), do: :edifice
  defp schedule_provider(:custom), do: :axon

  defp peft_provider(:edifice), do: :edifice
  defp peft_provider(:custom), do: :lorax
end
