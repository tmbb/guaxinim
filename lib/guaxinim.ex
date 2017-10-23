# **TODO**: Refactor this ASAP
defmodule Guaxinim do
  alias Guaxinim.Internal.SourceProcessor
  alias Guaxinim.Internal.SourceFormatter
  alias Guaxinim.BeamInspector
  alias Guaxinim.Config
  import Guaxinim.Utils.Path, only: [path: 1]
  alias Guaxinim.Config
  require EEx

  @doc """
  Prepare the destination directory
  """
  def prepare_dst(config) do
    # Clean the already existing files (oportunity for caching)
    if File.exists?(config.dst) and File.dir?(config.dst) do
      File.rm_rf!(config.dst)
    end
    # Create the destination directory
    File.mkdir_p!(config.dst)
    # Copy the static assets
    dst_static = Path.join(config.dst, "_static")
    File.cp_r!("priv/static", dst_static)
    :ok
  end

  def all_relative_files(root) do
    paths = Path.wildcard(root <> "/**/*.ex") ++ Path.wildcard(root <> "/*.ex")
    Enum.map(paths, fn path -> Path.relative_to(path, root) end)
  end

  def all_relative_dirs(root) do
    child_paths =
      Path.wildcard(root <> "/**")
      |> Enum.filter(fn path -> File.dir?(path) end)
      |> Enum.map(fn path -> Path.relative_to(path, root) end)

    ["" | child_paths]
  end

  def run() do
    config = Config.from_mix()
    BeamInspector.gather_data_from_modules(config)
    prepare_dst(config)

    config.src
    |> all_relative_files
    |> Enum.map(fn path -> process_file(path, config) end)

    config.src
    |> all_relative_dirs
    |> Enum.map(fn path -> create_index_file(path, config) end)

    :ok
  end


  def create_index_file(directory, config) do
    abs_directory = Path.join(config.src, directory)

    {sibling_directories, sibling_files} =
      child_directories_and_files(abs_directory)

    file = Path.join(directory, "index.html")

    assigns = %{
      project_title: config.project_title,
      sibling_directories: sibling_directories,
      sibling_files: sibling_files,
      config: config,
      file: file,
      content: ""
    }

    html = render_code_page(assigns)
    output_file = Path.join(config.dst, file)
    write_with_mkdir(output_file, html)
  end

  def process_file(file, config) do
    abs_file = Path.join(config.src, file)
    root_dirname = Path.dirname(abs_file)

    {sibling_directories, sibling_files} =
      child_directories_and_files(root_dirname)

    source = File.read!(abs_file)

    data = SourceProcessor.process_source(file, source)
    content = SourceFormatter.blocks_to_html(config, data)

    assigns = %{
      project_title: config.project_title,
      sibling_directories: sibling_directories,
      sibling_files: sibling_files,
      config: config,
      file: file,
      content: content
    }

    html = render_code_page(assigns)
    output_file = Path.join(config.dst, file <> ".html")
    write_with_mkdir(output_file, html)
  end


  def child_directories_and_files(parent_dir) do
    children =
      parent_dir
      |> File.ls!
      |> Enum.reject(fn path -> path == "index.md" end)

    child_directories =
      children
      |> Enum.filter(fn path -> parent_dir |> Path.join(path) |> File.dir? end)
      |> Enum.sort

    child_files =
      children
      |> Enum.filter(fn path ->
        full_path = Path.join(parent_dir, path)
        not File.dir?(full_path) and Path.extname(path) == ".ex"
      end)
      |> Enum.sort

    {child_directories, child_files}
  end

  def write_with_mkdir(output_file, content) do
    dirname = Path.dirname(output_file)
    # Ensure the directory exists.
    # To do this, we try to create the directory and ignore
    # both the `:ok` result (which means we've succeeded)
    # and the `{:error, :eexist}` result (which means the directory already existed)
    # Raise an error in case we get any other `{:error, _}` value.
    case File.mkdir_p(dirname) do
      :ok -> nil
      {:error, :eexist} -> nil
    end
    File.write!(output_file, content)
  end

  # Convenience functions to render the templates
  @external_resource "lib/guaxinim/templates/layout/master.html.eex"
  EEx.function_from_file(:defp, :render_code_page,
    "lib/guaxinim/templates/layout/master.html.eex",
    [:assigns])

  @external_resource "lib/guaxinim/templates/layout/sidebar.html.eex"
  EEx.function_from_file(:defp, :render_sidebar,
    "lib/guaxinim/templates/layout/sidebar.html.eex",
    [:assigns])
end
