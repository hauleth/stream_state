defmodule StreamState.Assertions do
  import ExUnit.Assertions, only: [assert: 2]

  @spec assert_state(state :: StreamState.result()) :: true
  def assert_state(%StreamState{result: :ok}), do: true

  def assert_state(%StreamState{result: {:failed, failure}, state: state, history: history}) do
    assert false, format_msg(failure, state, history)
  end

  defp format_msg({:post, cmd, result}, state, history) do
    """
    Postcondition failed.

    Current state: #{inspect(state)}

    History:

    #{print_history(history)}

    Failed:

      Command: #{print_command(cmd)}
      Result:  #{inspect(result)}
    """
  end

  defp format_msg({:pre, cmd}, state, history) do
    """
    Precondition failed.

    Current state: #{inspect(state)}

    History:

    #{print_history(history)}

    Failed:

      Command: #{print_command(cmd)}
    """
  end

  defp print_command({:call, mod, func, args}) do
    pretty_args =
      args
      |> Enum.map(&inspect/1)
      |> Enum.join(", ")

    "#{inspect(mod)}.#{func}(#{pretty_args})"
  end

  defp print_history(history) do
    history
    |> Enum.reverse()
    |> Enum.map(fn {_, cmd, ret} -> print_command(cmd) <> " => #{inspect(ret)}" end)
    |> Enum.join("\n")
  end
end
