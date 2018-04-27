defmodule Ellie.Elm.Platform.Impl19 do
  alias Ellie.Elm.Project
  alias Ellie.Elm.Name
  alias Ellie.Elm.Platform.Parser
  require Logger

  @behaviour Ellie.Elm.Platform

  def setup(root) do
    write_project!(root, %Project{}) # write default project file
    File.mkdir_p!(Path.join(root, "src"))
    with :ok <- install_by_name(root, Name.core()),
      :ok <- install_by_name(root, Name.html()),
      :ok <- install_by_name(root, Name.browser())
    do
      :ok
    else
      error -> error
    end
  end

  defp install_by_name(root, name) do
    binary = Application.app_dir(:ellie, "priv/bin/0.19.0/elm")
    args = ["--num", "1", binary, "install", Name.to_string(name)]
    options = [out: :string, err: :string, dir: root]
    result = Porcelain.exec("sysconfcpus", args, options)
    Logger.info("elm install\nexit: #{inspect result}\n")
    case result do
      %Porcelain.Result{status: 0} ->
        :ok
      %Porcelain.Result{status: other} ->
        {:error, "install exited with code #{other}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def compile(options) do
    %{root: root, entry: entry, output: output} = Enum.into(options, %{})
    binary = Application.app_dir(:ellie, "priv/bin/0.19.0/elm")
    args = ["--num", "1", binary, "make", entry, "--debug", "--output", output, "--report", "json"]
    options = [dir: root, out: :string, err: :string]
    result = Porcelain.exec("sysconfcpus", args, options)
    Logger.info("elm make\nexit: #{result.status}\nstdout: #{result.out}\nstderr: #{result.err}\n")
    case result do
      %Porcelain.Result{err: err, status: 0} ->
        {:ok, Parser.error_0_19_0(err)}
      %Porcelain.Result{err: err, out: out, status: other} ->
        {:error, "compiler exited with code #{other}\nstdout: #{out}\nstderr:#{err}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def format(code) do
    binary = Application.app_dir(:ellie, "priv/bin/0.19.0/elm-format")
    args = ["--stdin"]
    options = [in: code, out: :string, err: :string]
    result = Porcelain.exec(binary, args, options)
    case result do
      %Porcelain.Result{err: "", out: out, status: 0} ->
        {:ok, out}
      _ ->
        {:error, "elm-format failed to run"}
    end
  end

  def install(root, packages) do
    project = read_project!(root)
    if not MapSet.equal?(packages, project.deps) do
      updated = %{ project | deps: packages, trans_deps: MapSet.new() }
      write_project!(root, updated)
    end
    :ok
  end

  def dependencies(root) do
    project = read_project!(root)
    {:ok, project.deps}
  end

  defp read_project!(root) do
    project_path = Path.expand("./elm.json", root)
    data = File.read!(project_path)
    project_json = Poison.decode!(data)
    {:ok, project} = Project.from_json(project_json)
    project
  end

  defp write_project!(root, project) do
    project_path = Path.expand("./elm.json", root)
    project_json = Project.to_json(project)
    data = Poison.encode!(project_json)
    File.write!(project_path, data)
  end
end
