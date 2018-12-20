defmodule StreamState do
  @moduledoc """
  Provides the API of `eqc_statem` with the grouped functions.
  """

  import StreamData
  import ExUnit.Assertions

  @type symbolic_state :: term()
  @type command :: {:call, module(), atom(), list()}

  defstruct history: [],
            state: nil,
            result: :ok

  def run_commands(commands) do
    commands
    |> Enum.reduce_while(%__MODULE__{}, fn cmd, acc ->
      cmd
      |> execute_cmd()
      |> case do
        {:ok, next_state} ->
          {:cont, update_history(next_state, acc)}

        {:pre, state, cmd} ->
          {:halt, struct(acc, result: {:failed, {:pre, cmd}}, state: state)}

        {:post, state, cmd, result} ->
          {:halt, struct(acc, result: {:failed, {:post, cmd, result}}, state: state)}
      end
    end)
  end

  def assert_state(%__MODULE__{result: :ok}), do: :ok

  def assert_state(%__MODULE__{result: {:failed, failure}, state: state, history: history}) do
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

  defp execute_cmd({state, {:call, mod, func, args} = cmd}) do
    unless call_precondition(state, cmd), do: throw(:pre)

    result = apply(mod, func, args)

    unless call_postcondition(state, cmd, result), do: throw({:post, result})

    {:ok, {state, cmd, result}}
  catch
    :pre -> {:pre, state, cmd}
    {:post, result} -> {:post, state, cmd, result}
  end

  defp update_history({state, _, _} = event, %__MODULE__{history: history} = test_state) do
    struct(test_state, state: state, history: [event | history])
  end

  defp command_list(mod) do
    mod.module_info(:exports)
    |> Stream.filter(fn {func, _arity} ->
      function_exported?(mod, :"#{func}_args", 1) or
        function_exported?(mod, :"#{func}_command", 1)
    end)
    |> Enum.map(fn {func, _arity} ->
      if function_exported?(mod, :"#{func}_args", 1) do
        args_fun = fn state -> constant(apply(mod, :"#{func}_args", [state])) end
        args = gen_call(mod, func, args_fun)
        {:cmd, mod, :"#{func}", args}
      else
        {:cmd, mod, :"#{func}", &apply(mod, :"#{func}_command", &1)}
      end
    end)
  end

  defp unfold(agg, _, _, 0) do
    bind(agg, fn {_, list} -> constant(Enum.reverse(list)) end)
  end

  defp unfold(agg, freq, cmd_list, size) do
    bind(agg, fn {state, acc} ->
      call =
        cmd_list
        |> Enum.map(fn {:cmd, _mod, func, arg_fun} ->
          {freq.(state, func), arg_fun.(state)}
        end)
        |> frequency()
        |> Enum.at(0)

      if call_precondition(state, call) do
        result = make_ref()
        next_state = call_next_state(call, state, result)

        unfold(
          tuple({constant(next_state), constant([{state, call} | acc])}),
          freq,
          cmd_list,
          size - 1
        )
      else
        unfold(tuple({constant(state), constant(acc)}), freq, cmd_list, size)
      end
    end)
  end

  # Generates a function, which expects a state to create the call tuple
  # with constants for module and function and an argument generator.
  defp gen_call(mod, fun, arg_fun) when is_atom(fun) and is_function(arg_fun, 1) do
    fn state -> {:call, mod, fun, arg_fun.(state)} end
  end

  @spec generate_commands(module) :: StreamData.t({symbolic_state(), command()})
  def generate_commands(mod) do
    cmd_list = command_list(mod)
    initial_state = constant(mod.initial_state())

    freq =
      if function_exported?(mod, :weight, 2) do
        &mod.weight/2
      else
        fn _state, _cmd -> 1 end
      end

    sized(fn size ->
      tuple({initial_state, constant([])})
      |> unfold(freq, cmd_list, size)
      |> filter(fn list ->
        Enum.all?(list, fn {state, call} -> call_precondition(state, call) end)
      end)
    end)
  end

  defp call_next_state({:call, mod, f, args}, state, result) do
    name = :"#{f}_next"

    if function_exported?(mod, name, 3) do
      apply(mod, :"#{f}_next", [state, args, result])
    else
      state
    end
  end

  defp call_precondition(state, {:call, mod, f, args}) do
    name = :"#{f}_pre"

    if function_exported?(mod, name, 2) do
      apply(mod, name, [state, args])
    else
      true
    end
  end

  defp call_postcondition(state, {:call, mod, f, args}, result) do
    name = :"#{f}_post"

    if function_exported?(mod, name, 3) do
      apply(mod, name, [state, args, result])
    else
      true
    end
  end
end
