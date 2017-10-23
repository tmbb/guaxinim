defmodule Guaxinim.AstInspector do
  defp functions_called_pre_walk({f, location, args} = ast_node, acc)
      when is_atom(f) and is_list(args) do
    {ast_node, [{{f, length(args)}, location } | acc]}
  end
  defp functions_called_pre_walk(ast_node, acc), do: {ast_node, acc}

  defp post_walk(ast_node, acc), do: {ast_node, acc}

  def functions_called_by(definitions, heads) do
    calls_per_head =
      for head <- heads,
          {_loc, _args, _context, ast} = head,
          {_, calls} = Macro.traverse(ast, [], &functions_called_pre_walk/2, &post_walk/2),
        do: calls


    calls_per_head
    |> List.flatten
    |> Enum.filter(fn {fun_arity, _} -> MapSet.member?(definitions, fun_arity) end)
  end

  defp aliases_to_string(aliases),
    do: aliases |> Enum.map(&Atom.to_string/1) |> Enum.join(".")

  defp module_reference_pre_walk(
      {macro,
       _,
       [{{:require, _, prefix_aliases},
         _,
         suffix_aliases}]}, acc) when macro == :require or macro == :alias do

    full_aliases = for {:__aliases__, meta, aliases} <- suffix_aliases,
      do: {aliases_to_string(prefix_aliases ++ aliases), meta}

    {nil, full_aliases ++ acc}
  end

  defp module_reference_pre_walk(ast_node, acc), do: {ast_node, acc}

  def module_imports_and_etc(file_ast) do
    {_, references} = Macro.traverse(file_ast, [], &module_reference_pre_walk/2, &post_walk/2)
    references
  end
end