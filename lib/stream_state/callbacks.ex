defmodule StreamState.Callbacks do
  @moduledoc false

  @spec get_states(module()) :: [{atom(), non_neg_integer()}]
  def get_states(mod) do
    mod.module_info(:exports)
    |> Enum.filter(fn {func, _arity} ->
      function_exported?(mod, :"#{func}_args", 1) or
        function_exported?(mod, :"#{func}_command", 1)
    end)
  end

  def call(name, {:call, mod, func, fargs}, state, extra_args \\ [], default \\ true) do
    name = :"#{func}_#{name}"
    args = [state, fargs | extra_args]

    if function_exported?(mod, name, length(args)) do
      apply(mod, name, args)
    else
      default
    end
  end
end
