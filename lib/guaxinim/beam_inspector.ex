defmodule Guaxinim.BeamInspector do
  @moduledoc """
  A module to gather information from `.beam` files
  """

  alias Mix.Tasks.Compile.Elixir, as: E
  import Mix.Compilers.Elixir, only: [
    read_manifest: 2, source: 1, module: 1,
  ]
  require Amnesia.Helper
  require Amnesia

  require Guaxinim.Database.{ModuleDefinition, FunctionDefinition, FunctionCall}
  alias Guaxinim.Database.{ModuleDefinition, FunctionDefinition, FunctionCall}

  alias Guaxinim.AstInspector

  @doc """
  Gets all data from all modules
  """
  def module_references() do
    module_sources =
      for manifest <- E.manifests(),
          manifest_data = read_manifest(manifest, ""),
          module(module: module, sources: sources) <- manifest_data,
          source <- sources,
          source = Enum.find(manifest_data, &match?(source(source: ^source), &1)),
        do: {module, source}

    Map.new module_sources, fn {module, source} ->
      source(runtime_dispatches: runtime_dispatches,
             compile_dispatches: compile_dispatches) = source

      {module, compile_dispatches ++ runtime_dispatches}
    end
  end

  def package_from_path(path) do
    path
    |> Path.dirname
    |> Path.dirname
    |> Path.basename
  end

  def flatten_dispatch(caller_module, file, {module, function_calls}) do
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

  def dispatches_to_function_calls(caller_module, file, dispatches) do
    dispatches
    |> Enum.map(fn dispatch -> flatten_dispatch(caller_module, file, dispatch) end)
    |> List.flatten
  end

  def file_references(config) do
    module_sources =
      for manifest <- E.manifests(),
          manifest_data = read_manifest(manifest, ""),
          module(module: module, sources: sources) <- manifest_data,
          source <- sources,
          source = Enum.find(manifest_data, &match?(source(source: ^source), &1)),
          do: {module, source}

    Enum.map(module_sources, fn {current, source} ->
      source(runtime_dispatches: runtime_nested,
             compile_dispatches: compile_nested,
             source: file_relative_to_mix) = source

      abs_file = Path.absname(file_relative_to_mix)
      rel_file = Path.relative_to(abs_file, config.src_root)

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

  # def gather_function_definitions_in_module(_, _, false), do: :ok
  def gather_function_definitions_in_module(config, {module_name, binary_path}, internal?) do
    with path when is_list(path) <- to_charlist(binary_path),
        # Some BEAM introspection magic here...
        {:ok, {_, [debug_info: {:debug_info_v1, backend, data}]}} <- :beam_lib.chunks(path, [:debug_info]),
        {:ok,
         %{definitions: defs,
           line: module_line,
           file: abs_file}} <- backend.debug_info(:elixir_v1, String.to_atom(module_name), data, []) do

      package = package_from_path(binary_path)
      file =
        case internal? do
          true -> Path.relative_to(abs_file, config.src_root)
          false -> abs_file
        end

      Amnesia.transaction do
        # We already have everything about the module
        %ModuleDefinition{
          m: module_name,
          file: file,
          line: module_line,
          internal?: internal?,
          package: package,
        } |> ModuleDefinition.write

        # Now we're redy to add the function definitions
        definitions = for {fun_arity, keyword, meta, _heads} <- defs, into: %MapSet{} do
          fun_line = Keyword.get(meta, :line)
          {fun, arity} = fun_arity
          fun_str = Atom.to_string(fun)

          %FunctionDefinition{
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
          } |> FunctionDefinition.write

          fun_arity
        end

        if internal? do
          # After we've added the function definitions,
          # we can add the internal function calls.
          for {{caller_fun, caller_arity}, _, _, heads} <- defs do
            calls = AstInspector.functions_called_by(definitions, heads)
            # TODO: Handle kernel functions!
            for {{callee_fun, callee_arity}, meta} <- calls do
              callee_line = Keyword.get(meta, :line)
              caller_module = module_name
              callee_fun_str = Atom.to_string(callee_fun)
              %FunctionCall{
                m: module_name,
                f: callee_fun_str,
                a: callee_arity,
                caller_mfa: {module_name, Atom.to_string(caller_fun), caller_arity},
                caller_module: caller_module,
                file: file,
                line: callee_line,
                f_file_line: {callee_fun_str, file, callee_line}
              } |> FunctionCall.write
            end
          end
        end

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
      |> Enum.map(&String.trim_leading(&1, "Elixir."))

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

  def gather_data_from_modules(config) do
    file_references(config)
    gather_data_from_modules__async_stream(config)
  end

  # Alternate implementations for benchmarking purposes

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