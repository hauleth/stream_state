defmodule StreamState.AssertionsTest do
  use ExUnit.Case, async: true

  alias StreamState.Assertions, as: Subject

  doctest Subject

  describe "assert_state/1" do
    test "succeeds when result is :ok" do
      assert Subject.assert_state(%StreamState{result: :ok})
    end

    test "throws ExUnit.AssertionError on failure" do
      command = {:call, Foo, :bar, []}

      assert_raise ExUnit.AssertionError, fn ->
        Subject.assert_state(%StreamState{result: {:failed, {:pre, command}}})
      end

      assert_raise ExUnit.AssertionError, fn ->
        Subject.assert_state(%StreamState{result: {:failed, {:post, command, nil}}})
      end
    end
  end
end
