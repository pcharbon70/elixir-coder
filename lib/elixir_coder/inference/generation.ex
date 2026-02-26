defmodule ElixirCoder.Inference.Generation do
  @moduledoc """
  Candidate generation entrypoint for inference flows.

  This module provides a deterministic interface that can run against either:
  - a provided generator callback (runtime/model integration), or
  - explicit candidate fixtures (tests and dry runs).
  """

  @type candidate :: %{
          code: String.t(),
          metadata: map(),
          score: float()
        }

  @spec generate(String.t(), map() | keyword(), keyword()) ::
          {:ok, [candidate()]} | {:error, term()}
  def generate(prompt, clarification_answers, opts \\ [])
      when is_binary(prompt) and is_list(opts) do
    max_candidates = Keyword.get(opts, :num_candidates, 5)

    with :ok <- validate_max_candidates(max_candidates),
         {:ok, raw_candidates} <- resolve_candidates(prompt, clarification_answers, opts),
         {:ok, normalized} <- normalize_candidates(raw_candidates),
         filtered <- Enum.take(normalized, max_candidates),
         :ok <- ensure_non_empty(filtered) do
      {:ok, rank_candidates(filtered)}
    end
  end

  defp resolve_candidates(prompt, clarification_answers, opts) do
    case Keyword.get(opts, :generator) do
      generator when is_function(generator, 3) ->
        case generator.(prompt, clarification_answers, opts) do
          {:ok, candidates} when is_list(candidates) -> {:ok, candidates}
          {:error, _reason} = error -> error
          candidates when is_list(candidates) -> {:ok, candidates}
          other -> {:error, {:invalid_generator_output, other}}
        end

      nil ->
        case Keyword.get(opts, :candidates) do
          candidates when is_list(candidates) -> {:ok, candidates}
          nil -> {:error, :no_generator_or_candidates}
          other -> {:error, {:invalid_candidates, other}}
        end

      other ->
        {:error, {:invalid_generator, other}}
    end
  end

  defp normalize_candidates(raw_candidates) do
    raw_candidates
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, []}, fn {candidate, index}, {:ok, acc} ->
      case normalize_candidate(candidate, index) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, candidates} -> {:ok, Enum.reverse(candidates)}
      {:error, _reason} = error -> error
    end
  end

  defp normalize_candidate(candidate, _index) when is_binary(candidate) do
    {:ok,
     %{
       code: candidate,
       metadata: %{},
       score: 0.0
     }}
  end

  defp normalize_candidate(%{code: code} = candidate, _index) when is_binary(code) do
    {:ok,
     %{
       code: code,
       metadata: Map.get(candidate, :metadata, %{}),
       score: to_score(Map.get(candidate, :score, 0.0))
     }}
  end

  defp normalize_candidate(%{"code" => code} = candidate, _index) when is_binary(code) do
    {:ok,
     %{
       code: code,
       metadata: Map.get(candidate, "metadata", %{}),
       score: to_score(Map.get(candidate, "score", 0.0))
     }}
  end

  defp normalize_candidate(other, index), do: {:error, {:invalid_candidate, index, other}}

  defp rank_candidates(candidates) do
    candidates
    |> Enum.sort_by(& &1.score, :desc)
  end

  defp ensure_non_empty([]), do: {:error, :no_candidates}
  defp ensure_non_empty(_candidates), do: :ok

  defp validate_max_candidates(value) when is_integer(value) and value > 0, do: :ok
  defp validate_max_candidates(value), do: {:error, {:invalid_num_candidates, value}}

  defp to_score(score) when is_float(score), do: score
  defp to_score(score) when is_integer(score), do: score * 1.0
  defp to_score(_other), do: 0.0
end
