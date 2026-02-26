defmodule ElixirCoder.Inference.CheckTest do
  use ExUnit.Case, async: true

  alias ElixirCoder.Inference.Check

  test "check_syntax validates valid code" do
    code = """
    defmodule Demo do
      def ok, do: :ok
    end
    """

    assert {:ok, ast} = Check.check_syntax(code)
    assert is_tuple(ast)
  end

  test "check_syntax returns structured error for invalid code" do
    code = """
    defmodule Demo do
      def oops(
    end
    """

    assert {:error, error} = Check.check_syntax(code)
    assert error.source == :syntax
    assert is_binary(error.description)
  end

  test "check_quality detects heuristic IO.inspect issue" do
    code = """
    defmodule Demo do
      def log(x), do: IO.inspect(x)
    end
    """

    assert {:error, issues} = Check.check_quality(code)
    assert Enum.any?(issues, &(&1.code == :io_inspect))
    assert Enum.all?(issues, &(&1.source == :quality))
  end

  test "check_security detects heuristic System.cmd issue" do
    code = """
    defmodule Demo do
      def run(cmd), do: System.cmd(cmd, [])
    end
    """

    assert {:error, issues} = Check.check_security(code)
    assert Enum.any?(issues, &(&1.code == :system_cmd))
    assert Enum.all?(issues, &(&1.source == :security))
  end
end
