# # Guaxinim.BeamInspector
#
# This module is not adequately named.
# It does inspect the BEAM fies but iit does a lot more than that.
# We must change the name to reflect this.
defmodule Guaxinim.BeamInspector do
  @moduledoc """
  A module to gather information from `.beam` files
  """

  # ## Imports
  #
  # Some tools to inspect the compile manifests, also used by `mix xref`
  alias Mix.Tasks.Compile.Elixir, as: E
  import Mix.Compilers.Elixir, only: [read_manifest: 2, source: 1, module: 1]
  # The module `Amnesia.Helper` must be required to avoid some problems with macros
  # defined by the `Amnesia` module. **TODO**: Fix this upstream
  require Amnesia.Helper
  require Amnesia
  # Modules related to the database
  require Guaxinim.Database.{ModuleDefinition, FunctionDefinition, FunctionCall}
  alias Guaxinim.Database.{ModuleDefinition, FunctionDefinition, FunctionCall}
  # Module that contains utilities to traverse the AST directly and gather data
  # without help from the compile manifests
  alias Guaxinim.AstInspector

  # ## Implementation
  #
  # Currently most of the functions are public.
  # They should probably turned into private functions to control which
  # data Guaxinim wants to expose toa  public API.
  # Most of these functions should be provided at a lower level by `Mix.Xref`.
  #
  # **TODO**: work with the core team to stabilize `Mix.Xref`'s API.

  # There are probably more reliable ways to extract the package
  # **TODO:** Investigate
  def package_from_path(path) do
    path
    |> Path.dirname
    |> Path.dirname
    |> Path.basename
  end

  def flatten_dispatch(caller_module, file, {module, function_calls}) do
    # Turn the `Mix.Xref` data for the given module into a flat list of function calls
    # to write to the Database.
    module_name = Atom.to_string(module)
    Enum.map(function_calls, fn {{fun, arity}, lines} ->
      fun_str = Atom.to_string(fun)
      Enum.map(lines, fn line ->
        %FunctionCall{
          m: module_name,
          f: fun_str,
          a: arity,
          caller_mfa: nil,
          caller_module: caller_module,
          file: file,
          line: line,
          f_file_line: {fun_str, file, line}
        }
      end)
    end) |> List.flatten
  end

  defp dispatches_to_function_calls(caller_module, file, dispatches) do
    # Turn the `Mix.Xref` data for the given module into a flat list of function calls
    # to write to the Database.
    dispatches
    |> Enum.map(fn dispatch -> flatten_dispatch(caller_module, file, dispatch) end)
    |> List.flatten
  end


  defp file_references(config) do
    # What follows in some manifest introspection magic.
    # This uses some private `Mix.Xref` APIs.
    # **TODO**: work with the core team to stabilize these APIs.
    module_sources =
      for manifest <- E.manifests(),
          manifest_data = read_manifest(manifest, ""),
          module(module: module, sources: sources) <- manifest_data,
          source <- sources,
          source = Enum.find(manifest_data, &match?(source(source: ^source), &1)),
          do: {module, source}

    # This is very fast (possibly the Elixir compiler has already done most of the work)
    # Parallelizing this loop is not a top priority but it's not hard to do if needed.
    Enum.map(module_sources, fn {current, source} ->
      source(runtime_dispatches: runtime_nested,
             compile_dispatches: compile_nested,
             source: file_relative_to_mix) = source

      abs_file = Path.absname(file_relative_to_mix)
      rel_file = Path.relative_to(abs_file, config.src)

      caller_module = Atom.to_string(current)
      runtime_function_calls = dispatches_to_function_calls(caller_module, rel_file, runtime_nested)
      compile_function_calls = dispatches_to_function_calls(caller_module, rel_file, compile_nested)
      function_calls = runtime_function_calls ++ compile_function_calls

      Amnesia.transaction do
        for function_call <- function_calls do
          FunctionCall.write(function_call)
        end
      end
    end)

    :ok
  end

  defp extract_definitions(defs, module_name, file, package, internal?) do
    # Extract the definitions into a `MapSet`.
    # A `MapSet` is better than a list because we'll need fast lookups later.
    # Rememeber that we will always have strings instead of atoms in the database.
    pairs =
      for {fun_arity, keyword, meta, _heads} <- defs do
        fun_line = Keyword.get(meta, :line)
        {fun, arity} = fun_arity
        fun_str = Atom.to_string(fun)

        fun_def = %FunctionDefinition{
          mfa: {module_name, fun_str, arity},
          m: module_name,
          f: fun_str,
          a: arity,
          internal?: internal?,
          package: package,
          file: file,
          line: fun_line,
          keyword: keyword,
          meta: meta
        }

        fun_arity = {fun, arity}

        {fun_arity, fun_def}
      end

      {fun_arities, fun_defs} = Enum.unzip(pairs)
      {MapSet.new(fun_arities), fun_defs}
  end

  defp extract_internal_function_calls(defs, definitions, module_name, file) do
    for {{caller_fun, caller_arity}, _, _, heads} <- defs do
      # Inspect the AST to get the call sites.
      # For this, we need the list of definitions
      # (click the link for the details)
      calls = AstInspector.functions_called_by(definitions, heads)

      for {{callee_fun, callee_arity}, meta} <- calls do
        callee_line = Keyword.get(meta, :line)
        callee_fun_str = Atom.to_string(callee_fun)
        # In these function calls, the `m` (the callee module) and the `caller_module`
        # are the same.
        %FunctionCall{
          m: module_name,
          f: callee_fun_str,
          a: callee_arity,
          caller_mfa: {module_name, Atom.to_string(caller_fun), caller_arity},
          caller_module: module_name,
          file: file,
          line: callee_line,
          f_file_line: {callee_fun_str, file, callee_line}
        }
      end
    end |> List.flatten
  end

  # Refactor and change the name!
  # This gets not only function definitions but also internal function calls, which we can't
  # obtain in any other way.
  def gather_function_definitions_in_module(config, {module_name, binary_path}, internal?) do
    with path when is_list(path) <- to_charlist(binary_path),
        # Some BEAM introspection magic here...
        # The goal is to get the list of definitions (`defs`)
        # **TODO**: Explain this
        {:ok, {_, [debug_info:
                    {:debug_info_v1,
                     backend,
                     data}]}} <- :beam_lib.chunks(path, [:debug_info]),
        {:ok,
         %{definitions: defs,
           line: module_line,
           file: abs_file}} <-
            # The following function call uses `String.to_atom/1`.
            # This is not very safe when used at runtime,
            # because it can leave the BEAM out of memory.
            # Because Guaxinim is not supposed to be used at runtime
            # it should not be too bad
            backend.debug_info(
             :elixir_v1,
             String.to_atom(module_name),
             data,
             []) do

      package = package_from_path(binary_path)

      file =
        case internal? do
          true -> Path.relative_to(abs_file, config.src)
          false -> abs_file
        end

      # We already have everything about the module
      module_definition =
        %ModuleDefinition{
          m: module_name,
          file: file,
          line: module_line,
          internal?: internal?,
          package: package,
        }

      # Now we're ready to extract the function definitions.
      {fun_arities, definitions} =
        extract_definitions(defs, module_name, file, package, internal?)
      # The naming has now become a little confusing: we have both `defs` and `definitions`.
      #   * `defs` contains the definitions AST
      #   * `definitions` contains the `MapSet` which we will use to lookup
      #     the right definition at each call site

      # IO.inspect(fun_arities)

      # After we've added the function definitions,
      # we can add the function calls internal to each module.
      # We only care about the function calls from the files in the current project,
      # so we'll do it for internal modules only
      internal_function_calls = case internal? do
        true -> extract_internal_function_calls(defs, fun_arities, module_name, file)
        false -> []
      end

      # Write everything to the database
      Amnesia.transaction do
        ModuleDefinition.write(module_definition)
        Enum.map(definitions, &FunctionDefinition.write/1)
        Enum.map(internal_function_calls, &FunctionCall.write/1)
        :ok
      end
    end
  end

  def modules_from_app_path(app_path) do
    ebin_path = Path.join(app_path, "ebin")
    rel_files =
      ebin_path
      |> File.ls!
      |> Enum.filter(&String.ends_with?(&1, ".beam"))

    module_names =
      rel_files
      |> Enum.map(&String.trim_trailing(&1, ".beam"))
      # |> Enum.map(&String.trim_leading(&1, "Elixir."))

    abs_files = Enum.map(rel_files, &Path.join(ebin_path, &1))

    Enum.zip([module_names, abs_files])
  end

  def abs_ls!(dir) do
    dir |> File.ls! |> Enum.map(&Path.join(dir, &1))
  end

  def all_modules(classifier) do
    Mix.Project.build_path()
      |> Path.join("lib")
      |> abs_ls!
      |> Enum.map(fn path -> {path, classifier.(path)} end)
      |> Enum.map(fn {path, classification} ->
          for module <- modules_from_app_path(path),
            do: {module, classification}
         end)
      |> List.flatten
  end

  def internal_app?(internal_app_names, app_path) do
    Enum.member?(internal_app_names, Path.basename(app_path))
  end

  # ### Gathering all the data
  #
  # The `gather_data_from_modules` is the main entry point for this module.
  # It has to perform a lot of work, which can be done mostly in parallel.
  # Currently, the parallelization is handled by `Task.async_stream`, because
  # that's shown to be the fastest implementation in the benchmarks, but three
  # implementations are provided:
  #
  #   1. A sequential one, which doesn't take advantage of multiple cores
  #   2. A parallel one using `Task.async`
  #   3. A parallel one using `Task.async_stream`
  #
  # If at any point the benchmarks show better performance with an alternative
  # approach, we will switch to a new parallelization strategy
  #
  # Another way to increase performance is through caching.
  # This is probably the next step.

  @doc """
  Gathers all the data we need to hyperlink the source.
  """
  def gather_data_from_modules(config) do
    file_references(config)
    gather_data_from_modules__async_stream(config)
  end

  # #### Alternate implementations for benchmarking purposes

  @doc false
  def gather_data_from_modules__sequential(config) do
    internal_app_names = [Path.basename(Mix.Project.app_path)]
    all_modules(fn path -> internal_app?(internal_app_names, path) end)
    |> Enum.map(fn {data, internal?} ->
        gather_function_definitions_in_module(config, data, internal?) end)
  end

  @doc false
  def gather_data_from_modules__async_stream(config) do
    internal_app_names = [Path.basename(Mix.Project.app_path)]

    all_modules(fn path -> internal_app?(internal_app_names, path) end)
    |> Task.async_stream(fn {data, internal?} ->
        gather_function_definitions_in_module(config, data, internal?) end)
    |> Stream.filter(fn {:ok, _} -> true; _ -> false end)
    |> Stream.map(fn {:ok, result} -> result end)
    |> Enum.to_list
  end

  @doc false
  def gather_data_from_modules__task_async(config) do
    internal_app_names = [Path.basename(Mix.Project.app_path)]
    all_modules(fn path -> internal_app?(internal_app_names, path) end)
    |> Enum.map(&Task.async(fn ->
         {data, internal?} = &1
         gather_function_definitions_in_module(config, data, internal?)
       end))
    |> Enum.map(&Task.await/1)
  end
end