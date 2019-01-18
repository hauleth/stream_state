ExUnit.start()

defmodule StreamStateTest do
  use ExUnit.Case
  use ExUnitProperties
  use StreamState

  require Logger

  defmodule Counter do
    @moduledoc """
    An `Agent`-based counter as an example for a stateful system.
    """

    use Agent

    @spec start_link(term) :: {:ok, pid}
    def start_link(_) do
      Agent.start_link(fn -> 0 end, name: __MODULE__)
    end

    @spec clear() :: :ok
    @spec clear(pid) :: :ok
    def clear(pid \\ __MODULE__) do
      Agent.update(pid, fn _ -> 0 end)
    end

    @spec get() :: integer
    @spec get(pid) :: integer
    def get(pid \\ __MODULE__) do
      Agent.get(pid, fn state -> state end)
    end

    @spec inc() :: :integer
    @spec inc(pid) :: :integer
    def inc(pid \\ __MODULE__) do
      Agent.get_and_update(pid, fn state ->
        new_state = state + 1
        {new_state, new_state}
      end)
    end
  end

  import StreamState

  property "greets the world" do
    check all cmds <- generate_commands(__MODULE__) do
      # Start system under test
      start_supervised!(Counter)

      state = run_commands(cmds)

      # Stop system under test
      stop_supervised(Counter)

      assert_state(state)
    end
  end

  def weight(_state, :inc), do: 3
  def weight(_state, _cmd), do: 1

  def initial_state(), do: :zero

  def inc, do: Counter.inc()
  def inc_args(_state), do: []
  def inc_next(_state, _args, _result), do: :one
  def inc_post(_state, _args, result), do: result != 6

  def clear, do: Counter.clear()
  def clear_args(_state), do: []
  def clear_next(_state, _args, _result), do: :zero

  def get, do: Counter.get()
  def get_args(_state), do: []
  def get_post(:one, _args, result) when is_integer(result), do: result > 0
  def get_post(:zero, _args, 0), do: true
  def get_post(_state, _args, _value), do: false
end
