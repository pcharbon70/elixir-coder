defmodule ElixirCoder.Inference.GenerationTest do
  use ExUnit.Case, async: true

  alias ElixirCoder.Inference.Generation

  test "generate returns ranked candidates from explicit candidate list" do
    assert {:ok, candidates} =
             Generation.generate("Implement function", %{},
               candidates: [
                 %{code: "def a, do: :a", score: 0.2},
                 %{code: "def b, do: :b", score: 0.9}
               ]
             )

    assert length(candidates) == 2
    assert hd(candidates).code == "def b, do: :b"
    assert hd(candidates).score == 0.9
  end

  test "generate can use generator callback and candidate cap" do
    generator = fn _prompt, _answers, _opts ->
      [
        %{code: "def c, do: :c", score: 0.5},
        %{code: "def d, do: :d", score: 0.4},
        %{code: "def e, do: :e", score: 0.3}
      ]
    end

    assert {:ok, candidates} =
             Generation.generate("Prompt", %{foo: :bar},
               generator: generator,
               num_candidates: 2
             )

    assert Enum.map(candidates, & &1.code) == ["def c, do: :c", "def d, do: :d"]
  end
end
