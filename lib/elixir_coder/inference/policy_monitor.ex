defmodule ElixirCoder.Inference.PolicyMonitor do
  @moduledoc """
  Aggregates inference policy telemetry into warn-only operational metrics.

  This monitor consumes:
  `[:elixir_coder, :inference, :policy, :evaluated]`

  And emits alert telemetry when configured thresholds are exceeded:
  `[:elixir_coder, :inference, :policy, :alert]`
  """

  use GenServer

  @table __MODULE__
  @handler_id "elixir-coder-inference-policy-monitor"
  @policy_event [:elixir_coder, :inference, :policy, :evaluated]
  @alert_event [:elixir_coder, :inference, :policy, :alert]

  @default_thresholds %{
    boundary_under_handling_rate: 0.20,
    internal_over_defensive_rate: 0.20,
    silent_failure_rate: 0.08
  }

  @type alert :: %{
          message: String.t(),
          metric:
            :boundary_under_handling_rate | :internal_over_defensive_rate | :silent_failure_rate,
          severity: :warn,
          threshold: float(),
          value: float()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) when is_list(opts) do
    GenServer.start_link(__MODULE__, %{}, Keyword.put_new(opts, :name, __MODULE__))
  end

  @impl true
  def init(_state) do
    ensure_table!()
    attach!()
    {:ok, %{}}
  end

  @impl true
  def terminate(_reason, _state) do
    detach!()
    :ok
  end

  @spec telemetry_event_names() :: %{alert: [atom()], policy_evaluated: [atom()]}
  def telemetry_event_names do
    %{
      alert: @alert_event,
      policy_evaluated: @policy_event
    }
  end

  @spec attach!() :: :ok
  def attach! do
    ensure_table!()

    case :telemetry.attach(@handler_id, @policy_event, &__MODULE__.handle_event/4, %{}) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end
  end

  @spec detach!() :: :ok
  def detach! do
    :telemetry.detach(@handler_id)
    :ok
  end

  @spec reset!() :: :ok
  def reset! do
    ensure_table!()
    :ets.delete_all_objects(@table)
    :ok
  end

  @spec record(map(), map()) :: :ok
  def record(measurements, metadata \\ %{}) when is_map(measurements) and is_map(metadata) do
    handle_event(@policy_event, measurements, metadata, %{})
  end

  @spec snapshot() :: map()
  def snapshot do
    ensure_table!()

    total = counter(:total)
    internal_sum = counter(:internal_sum)
    boundary_sum = counter(:boundary_sum)
    silent_sum = counter(:silent_sum)
    compliant_sum = counter(:compliant_sum)
    violation_sum = counter(:violation_sum)

    %{
      average_violation_count: rate(violation_sum, total),
      boundary_under_handling_rate: rate(boundary_sum, total),
      by_backend: %{
        custom: backend_snapshot(:custom),
        edifice: backend_snapshot(:edifice)
      },
      count: total,
      internal_over_defensive_rate: rate(internal_sum, total),
      policy_compliance_rate: rate(compliant_sum, total),
      silent_failure_rate: rate(silent_sum, total)
    }
  end

  @spec check_alerts(keyword() | map()) :: [alert()]
  def check_alerts(threshold_opts \\ [])

  def check_alerts(threshold_opts) when is_list(threshold_opts) do
    check_alerts(Map.new(threshold_opts))
  end

  def check_alerts(threshold_overrides) when is_map(threshold_overrides) do
    current = snapshot()
    thresholds = Map.merge(@default_thresholds, threshold_overrides)

    alerts =
      [
        {:internal_over_defensive_rate, current.internal_over_defensive_rate},
        {:boundary_under_handling_rate, current.boundary_under_handling_rate},
        {:silent_failure_rate, current.silent_failure_rate}
      ]
      |> Enum.flat_map(fn {metric, value} ->
        threshold = Map.fetch!(thresholds, metric)

        if value > threshold do
          [
            %{
              message:
                "#{metric} exceeded threshold (value=#{format_rate(value)}, threshold=#{format_rate(threshold)})",
              metric: metric,
              severity: :warn,
              threshold: threshold,
              value: value
            }
          ]
        else
          []
        end
      end)

    emit_alerts(alerts, current)
    alerts
  end

  @doc false
  def handle_event(@policy_event, measurements, metadata, _config) do
    ensure_table!()

    count = metric_int(measurements, :count, 1)
    internal = metric_int(measurements, :internal_over_defensive_rate, 0)
    boundary = metric_int(measurements, :boundary_under_handling_rate, 0)
    silent = metric_int(measurements, :silent_failure_rate, 0)
    compliant = metric_int(measurements, :policy_compliant, 0)
    violations = metric_int(measurements, :violation_count, 0)

    increment(:total, count)
    increment(:internal_sum, internal)
    increment(:boundary_sum, boundary)
    increment(:silent_sum, silent)
    increment(:compliant_sum, compliant)
    increment(:violation_sum, violations)

    case parse_backend(Map.get(metadata, :backend) || Map.get(metadata, "backend")) do
      backend when backend in [:edifice, :custom] ->
        increment({:backend_total, backend}, count)
        increment({:backend_internal_sum, backend}, internal)
        increment({:backend_boundary_sum, backend}, boundary)
        increment({:backend_silent_sum, backend}, silent)
        increment({:backend_compliant_sum, backend}, compliant)
        increment({:backend_violation_sum, backend}, violations)

      nil ->
        :ok
    end

    :ok
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok

  defp emit_alerts([], _snapshot), do: :ok

  defp emit_alerts(alerts, snapshot) do
    :telemetry.execute(@alert_event, %{count: length(alerts)}, %{
      alerts: alerts,
      snapshot: snapshot
    })
  end

  defp backend_snapshot(backend) do
    total = counter({:backend_total, backend})

    %{
      average_violation_count: rate(counter({:backend_violation_sum, backend}), total),
      boundary_under_handling_rate: rate(counter({:backend_boundary_sum, backend}), total),
      count: total,
      internal_over_defensive_rate: rate(counter({:backend_internal_sum, backend}), total),
      policy_compliance_rate: rate(counter({:backend_compliant_sum, backend}), total),
      silent_failure_rate: rate(counter({:backend_silent_sum, backend}), total)
    }
  end

  defp metric_int(measurements, key, default) do
    measurements
    |> Map.get(key, default)
    |> normalize_int(default)
  end

  defp normalize_int(value, _default) when is_integer(value), do: value
  defp normalize_int(value, _default) when is_float(value), do: round(value)
  defp normalize_int(_value, default), do: default

  defp counter(key) do
    case :ets.lookup(@table, key) do
      [{^key, value}] -> value
      _ -> 0
    end
  end

  defp increment(key, value) when is_integer(value) do
    :ets.update_counter(@table, key, {2, value}, {key, 0})
    :ok
  end

  defp rate(_sum, 0), do: 0.0
  defp rate(sum, total), do: sum / total

  defp ensure_table! do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [
          :named_table,
          :public,
          :set,
          read_concurrency: true,
          write_concurrency: true
        ])

        :ok

      _table ->
        :ok
    end
  end

  defp parse_backend(value) when value in [:edifice, :custom], do: value

  defp parse_backend(value) when is_binary(value) do
    case value do
      "edifice" -> :edifice
      "custom" -> :custom
      _ -> nil
    end
  end

  defp parse_backend(_other), do: nil

  defp format_rate(value) do
    :erlang.float_to_binary(value * 1.0, decimals: 3)
  end
end
