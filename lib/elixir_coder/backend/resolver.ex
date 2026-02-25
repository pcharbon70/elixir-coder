defmodule ElixirCoder.Backend.Resolver do
  @moduledoc """
  Resolves backend choice for a required feature set.

  Resolution is Edifice-first by default and can fall back to `:custom` when
  configured and supported.
  """

  alias ElixirCoder.Backend.CapabilityRegistry

  @type backend :: CapabilityRegistry.backend()
  @type feature :: CapabilityRegistry.feature()

  @type resolution_metadata :: %{
          fallback?: boolean(),
          fallback_backend: backend(),
          missing_features: [feature()],
          requested_backend: backend()
        }

  @type unsupported_details :: %{
          fallback_backend: backend(),
          fallback_missing_features: [feature()],
          missing_features: [feature()],
          requested_backend: backend()
        }

  @spec resolve(backend(), [feature()], keyword()) ::
          {:ok, backend(), resolution_metadata()}
          | {:error, {:unsupported_features, unsupported_details()}}
  def resolve(requested_backend, required_features, opts \\ []) do
    fallback_backend = Keyword.get(opts, :fallback_backend, :custom)
    allow_fallback? = Keyword.get(opts, :allow_fallback?, true)

    requested_missing =
      CapabilityRegistry.missing_features(requested_backend, required_features)

    case {requested_missing, allow_fallback?} do
      {[], _} ->
        {:ok, requested_backend,
         %{
           fallback?: false,
           fallback_backend: fallback_backend,
           missing_features: [],
           requested_backend: requested_backend
         }}

      {_missing, false} ->
        {:error,
         {:unsupported_features,
          %{
            fallback_backend: fallback_backend,
            fallback_missing_features: requested_missing,
            missing_features: requested_missing,
            requested_backend: requested_backend
          }}}

      {_missing, true} ->
        fallback_missing =
          CapabilityRegistry.missing_features(fallback_backend, required_features)

        if fallback_missing == [] do
          {:ok, fallback_backend,
           %{
             fallback?: true,
             fallback_backend: fallback_backend,
             missing_features: requested_missing,
             requested_backend: requested_backend
           }}
        else
          {:error,
           {:unsupported_features,
            %{
              fallback_backend: fallback_backend,
              fallback_missing_features: fallback_missing,
              missing_features: requested_missing,
              requested_backend: requested_backend
            }}}
        end
    end
  end
end
