defmodule StreamStateTest do
  @moduledoc """
  Tests the functions from `StateM`. The reference modul is `cache_eqc_test.exs`,
  i.e. `CounterTest.Cache.Eqc`
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias StreamState, as: Subject

  doctest Subject

  def simple_call(arg), do: send(self(), {:simple, arg})

  describe "run_commands/1" do
    property "runs provided function with given argument" do
      check all arg <- term() do
        commands = [
          {nil, {:call, __MODULE__, :simple_call, [arg]}}
        ]

        _ = Subject.run_commands(commands)

        assert_received {:simple, _arg}
      end
    end

    property "given function is ran expected amount of times" do
      command = {nil, {:call, __MODULE__, :simple_call, [nil]}}

      check all commands <- list_of(constant(command), min_lenght: 1) do
        _ = Subject.run_commands(commands)

        for _ <- commands do
          assert_received {:simple, _}
        end
      end
    end
  end

  describe "generate_commands/1" do
    defmodule SimpleTest do
      def initial_state, do: nil

      def foo, do: nil
      def foo_args(_), do: []
    end

    test "returns StreamData" do
      assert %StreamData{} = Subject.generate_commands(SimpleTest)
    end

    property "always generate at least one element" do
      check all commands <- Subject.generate_commands(SimpleTest) do
        assert length(commands) > 0
      end
    end

    property "generate entries are tuples of state and call" do
      check all commands <- Subject.generate_commands(SimpleTest) do
        for command <- commands do
          assert {_, {:call, SimpleTest, :foo, _}} = command
        end
      end
    end
  end
end
