defmodule ElixirCoder.Backend.CapabilityRegistry do
  @moduledoc """
  Registry of feature support across execution backends.

  The project defaults to Edifice-backed implementations where possible, while
  allowing a custom fallback path for unsupported features.
  """

  @type backend :: :edifice | :custom

  @type feature ::
          :adapter_injection
          | :distillation
          | :inference_generation
          | :legacy_attention
          | :model_blocks
          | :optimizer
          | :peft
          | :policy_enforcement
          | :pruning
          | :quantization
          | :schedule

  @backend_features %{
    edifice:
      MapSet.new([
        :adapter_injection,
        :distillation,
        :inference_generation,
        :model_blocks,
        :optimizer,
        :peft,
        :policy_enforcement,
        :pruning,
        :quantization,
        :schedule
      ]),
    custom:
      MapSet.new([
        :adapter_injection,
        :inference_generation,
        :legacy_attention,
        :model_blocks,
        :optimizer,
        :peft,
        :policy_enforcement,
        :schedule
      ])
  }

  @spec backends() :: [backend()]
  def backends, do: Map.keys(@backend_features)

  @spec capabilities(backend()) :: MapSet.t(feature())
  def capabilities(backend) do
    Map.get(@backend_features, backend, MapSet.new())
  end

  @spec supports?(backend(), feature()) :: boolean()
  def supports?(backend, feature) do
    MapSet.member?(capabilities(backend), feature)
  end

  @spec missing_features(backend(), [feature()]) :: [feature()]
  def missing_features(backend, required_features) when is_list(required_features) do
    backend_features = capabilities(backend)

    required_features
    |> Enum.uniq()
    |> Enum.reject(&MapSet.member?(backend_features, &1))
  end
end
