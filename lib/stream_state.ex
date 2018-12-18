defmodule StreamState do
  @moduledoc """
  Provides the API of `eqc_statem` with the grouped functions.
  """

  alias StreamData.LazyTree

  import StreamData

  defstruct history: [],
            state: nil,
            result: :ok

  def run_commands(commands) do
    import ExUnit.Assertions

    commands
    |> Enum.reduce(%__MODULE__{}, fn cmd, acc ->
      cmd
      |> execute_cmd()
      |> case do
        {:ok, next_state} ->
          next_state

        {:pre, state, cmd} ->
          assert false, """
          Precondition failed.

          Command: #{print_command(cmd)}
          State:   #{inspect(state)}

          History:
          #{print_history(acc)}
          """

        {:post, state, cmd, result} ->
          assert false, """
          Postcondition failed.

          Command: #{print_command(cmd)}
          State:   #{inspect(state)}
          Result:  #{inspect(result)}

          History:
          #{print_history(acc)}
          """
      end
      |> update_history(acc)
    end)
    |> struct(result: :ok)
  end

  defp print_command({:call, mod, func, args}) do
    pretty_args =
      args
      |> Enum.map(&inspect/1)
      |> Enum.join(", ")

    "#{inspect(mod)}.#{func}(#{pretty_args})"
  end

  defp print_history(%__MODULE__{history: history}) do
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

  defp update_history({state, _, result} = event, %__MODULE__{history: history}) do
    %__MODULE__{state: state, result: result, history: [event | history]}
  end

  defp command_list(mod) do
    mod.module_info(:exports)
    |> Stream.filter(fn {func, _arity} ->
      function_exported?(mod, :"#{func}_args", 1) or
        function_exported?(mod, :"#{func}_command", 1)
    end)
    |> Enum.map(fn {func, _arity} ->
      if function_exported?(mod, :"#{func}_args", 1) do
        args_fun = fn state -> apply(mod, :"#{func}_args", [state]) end
        args = gen_call(mod, func, args_fun)
        {:cmd, mod, :"#{func}", args}
      else
        {:cmd, mod, :"#{func}", &apply(mod, :"#{func}_command", &1)}
      end
    end)
  end

  # Generates a function, which expects a state to create the call tuple
  # with constants for module and function and an argument generator.
  defp gen_call(mod, fun, arg_fun) when is_atom(fun) and is_function(arg_fun, 1) do
    fn state -> {:call, mod, fun, arg_fun.(state)} end
  end

  @spec generate_commands(module) :: StreamData.LazyTree.t()
  def generate_commands(mod) do
    cmd_list = command_list(mod)

    new(fn seed, size ->
      gen_cmd_list(mod.initial_state(), mod, cmd_list, size, 1, seed)
      |> LazyTree.zip()
      # min size is 1
      |> LazyTree.map(&command_lazy_tree(&1, 1))
      |> LazyTree.flatten()
      # this is like list_uniq: filter out invalid values
      |> LazyTree.filter(&check_preconditions(&1))
    end)
  end

  defp gen_cmd_list(_state, _mod, _cmd_list, 0, _position, _seed), do: []

  defp gen_cmd_list(state, mod, cmd_list, size, position, seed) do
    {seed1, seed2} = split_seed(seed)
    start_state = StreamData.constant(state)

    freq =
      if function_exported?(mod, :weight, 2) do
        &mod.weight/2
      else
        fn _state, _cmd -> 1 end
      end

    calls =
      cmd_list
      |> Enum.map(fn {:cmd, _mod, func, arg_fun} ->
        {freq.(state, func), arg_fun.(state)}
      end)
      |> frequency()

    tree = StreamData.__call__({start_state, calls}, seed1, size)
    {gen_state, generated_call} = tree.root

    if call_precondition(gen_state, generated_call) do
      gen_result = {:var, position}
      next_state = call_next_state(generated_call, gen_state, gen_result)
      [tree | gen_cmd_list(next_state, mod, cmd_list, size - 1, position + 1, seed2)]
    else
      gen_cmd_list(state, mod, cmd_list, size, position, seed2)
    end
  end

  defp call_next_state({:call, mod, f, args}, state, result) do
    name = :"#{f}_next"

    if function_exported?(mod, name, 3) do
      apply(mod, :"#{f}_next", [state, args, result])
    else
      state
    end
  end

  defp check_preconditions(list) do
    Enum.all?(list, fn {state, call} -> call_precondition(state, call) end)
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

  @spec command_lazy_tree([{state_t, LazyTree.t()}], non_neg_integer) :: LazyTree.t()
  defp command_lazy_tree(list, min_length) do
    length = length(list)

    if length == min_length do
      lazy_tree_constant(list)
    else
      # in contrast to lists we shrink from the end
      # towards the front and have a minimum list of 1
      # element: The initial command.
      children =
        Stream.map((length - 1)..1, fn index ->
          command_lazy_tree(List.delete_at(list, index), min_length)
        end)

      lazy_tree(list, children)
    end
  end

  ##########
  ## Borrowed from StreamData
  @type state_t :: any

  defp new(generator) when is_function(generator, 2) do
    %StreamData{generator: generator}
  end

  defp lazy_tree(root, children) do
    %LazyTree{root: root, children: children}
  end

  defp lazy_tree_constant(term) do
    %LazyTree{root: term}
  end

  if String.to_integer(System.otp_release()) >= 20 do
    @rand_algorithm :exsp
  else
    @rand_algorithm :exs64
  end

  defp split_seed(seed) do
    {int, seed} = :rand.uniform_s(1_000_000_000, seed)
    new_seed = :rand.seed_s(@rand_algorithm, {int, 0, 0})
    {new_seed, seed}
  end
end
