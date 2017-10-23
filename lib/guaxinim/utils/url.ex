defmodule Guaxinim.Utils.URL do
  require Amnesia
  # **TODO**: This module must be required because somehow the `Amnesia`
  # module uses macros from `Amnesia.Helper` without requiring it.
  # we must see if this can be fixed with a PR to `Amnesia`
  require Amnesia.Helper
  alias Guaxinim.Database.FunctionDefinition
  require FunctionDefinition
  import Guaxinim.Utils.Path, only: [path: 1]
  # ## Rationale
  #
  # The main entry point for this module is the `url_for_mfa` function.
  # It handles the task of finding the URL to a function or macro definition,
  # given the function's module, name and arity.
  # Functions can come from at least 3 places:
  #
  #   1. The Elixir standard library (must start with `"Elixir."`)
  #   2. The Erlang standard library
  #   3. A package we've imported from Hex (it can be an Elixir or Erlang package)
  #   4. The current project
  #
  #
  # Functions defined in the current project or in an external package
  # were previously stored in the Database as a preprocessing step.
  # Those are the ones that require a Mnesia query.
  #
  # Functions from the Elixir standard library can be identified through the module name.
  # We will assume that all functions that don't appear in the database and whose module
  # starts with a lowercase letter are Erlang functions from the standard library.
  #
  # It's not clear that these assumptions are sound, but they're good enough for now.

  @doc """
  URL for a given function. The function is given as `{module, function, arity}`,
  where `module` and `function` are strings instead of atoms.
  """
  def url_for_mfa(config, src, mfa) do
    # We already know that we're not dealing with an Elixir function
    # from the standard library.
    # At this point there are only three cases we must handle:
    #
    #   1. Internal functions, defined in the current project
    #   2. External Elixir functions, downloaded from an external package
    #   3. Erlang functions from the standard library
    #
    # The first two kinds of functions can be found in the database.
    # The Erlang functions can't.
    case FunctionDefinition.read!(mfa) do
      %{internal?: true, file: dst, line: line} ->
        url_internal(config, src, dst, line)

      %{internal?: false, package: package} ->
        url_mfa_hexdocs(package, mfa)

      nil ->
        case mfa do
          # If the module:
          #
          #   1. is not a built-in Elixir module module;
          #   2. has a name starting with a lowercase letter *and*
          #   3. can't be found amongs our packages
          #
          # we assume it's a built-in Erlang module and link to the erlang docs,
          {<< m0 >> <> _, _, _} when ?a <= m0 and m0 <= ?z ->
            url_for_builtin_erlang_module(mfa)

          {"EEx." <> _, _f, _a} ->
            url_mfa_hexdocs("eex", mfa)

          _ ->
            url_mfa_hexdocs("elixir", mfa)
        end
    end
  end

  @doc """
  URL for an Erlang function from the standard library
  (given as `{module, function, arity}`)
  """
  def url_for_builtin_erlang_module({m, f, a}) do
    # Thankfully the Erlang docs follow a predictable format.
    "http://erlang.org/doc/man/#{m}.html##{f}-#{a}"
  end

  @doc """
  URL for a function (given as `{module, function, arity}`) from a Hex package.
  """
  def url_mfa_hexdocs(package, {m, f, a}) do
    trimmed = String.trim_leading(m, "Elixir.")
    "https://hexdocs.pm/#{package}/#{trimmed}.html##{f}/#{a}"
  end

  @doc """
  URL for functions defined in the current project.
  """
  def url_internal(_config, src, dst, line) do
    base = path(from: src, to: dst)
    # Link to the anchor of the line where the function is defined:
    case base do
      "" -> "#L#{line}"
      _ -> "#{base}.html##{line}"
    end
  end

end