defmodule ElixirCoder.Inference.RepairTest do
  use ExUnit.Case, async: true

  alias ElixirCoder.Inference.Repair

  test "build_prompt includes original prompt, failed code, and issues" do
    prompt = "Implement API boundary handler"

    failed_code = """
    def create(params) do
      payload = Jason.decode!(params["payload"])
      {:ok, payload}
    end
    """

    issues = [
      %{source: :quality, code: :io_inspect, message: "Avoid IO.inspect", line: 2},
      %{source: :security, code: :system_cmd, message: "System.cmd is unsafe", line: 3}
    ]

    repair_prompt = Repair.build_prompt(prompt, failed_code, issues)

    assert repair_prompt =~ "Original Request"
    assert repair_prompt =~ "Failed Candidate"
    assert repair_prompt =~ "Detected Issues"
    assert repair_prompt =~ "Avoid IO.inspect"
    assert repair_prompt =~ "System.cmd is unsafe"
    assert repair_prompt =~ prompt
  end
end
