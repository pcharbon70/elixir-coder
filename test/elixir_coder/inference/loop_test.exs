defmodule ElixirCoder.Inference.LoopTest do
  use ExUnit.Case, async: true

  alias ElixirCoder.Inference.Loop

  test "generate_with_repair returns first clean candidate" do
    generation_opts = [
      candidates: [
        %{code: "defmodule A do def ok, do: :ok end", score: 0.9},
        %{code: "defmodule B do def nope, do: IO.inspect(:x) end", score: 0.1}
      ]
    ]

    assert {:ok, result} =
             Loop.generate_with_repair("Implement internal helper", %{},
               generation_opts: generation_opts,
               context: :supervised_internal,
               policy_mode: :warn
             )

    assert result.code =~ "defmodule A"
    assert result.attempt == 1
    assert result.checks.syntax == :ok
    assert result.checks.quality == :ok
    assert result.checks.security == :ok
  end

  test "generate_with_repair repairs failed candidate and succeeds on second attempt" do
    generation_opts = [
      candidates: [
        %{
          code: """
          def handle_cast(msg, state) do
            try do
              process(msg, state)
            rescue
              _ -> :ok
            end
          end
          """
        }
      ]
    ]

    repair_generator = fn _repair_prompt, _failed_code, _ctx ->
      {:ok,
       """
       def handle_cast(msg, state) do
         process(msg, state)
         {:noreply, state}
       end
       """}
    end

    assert {:ok, result} =
             Loop.generate_with_repair("Implement GenServer callback", %{},
               generation_opts: generation_opts,
               repair_generator: repair_generator,
               context: :supervised_internal,
               policy_mode: :enforce,
               max_attempts: 3
             )

    assert result.attempt == 2
    assert result.repair_history != []
    assert result.code =~ "{:noreply, state}"
    assert result.checks.policy == :ok
  end

  test "generate_with_repair terminates with error when max attempts reached" do
    generation_opts = [
      candidates: [
        %{code: "def create(params), do: Jason.decode!(params[\"payload\"]) || raise(\"bad\")"}
      ]
    ]

    repair_generator = fn _repair_prompt, failed_code, _ctx ->
      {:ok, failed_code}
    end

    assert {:error, {:no_clean_candidate, details}} =
             Loop.generate_with_repair("Build boundary API handler", %{},
               generation_opts: generation_opts,
               repair_generator: repair_generator,
               context: :boundary_handling,
               policy_mode: :enforce,
               max_attempts: 2
             )

    assert details.attempts == 2
    assert details.issues != []
    assert details.repair_history != []
  end
end
