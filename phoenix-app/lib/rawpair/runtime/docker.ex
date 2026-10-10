defmodule RawPair.Runtime.Docker do
  @behaviour RawPair.Runtime.Backend
  alias RawPair.Docker.WorkspaceManager
  alias RawPair.DockerClient
  @root "/home/devuser/app"

  def configure(workspace) do
    if DockerClient.running?("workspace-#{workspace.slug}"),
      do: {:error, "Stop workspace before changing configuration"},
      else: {:ok, %{}}
  end

  def start(workspace), do: WorkspaceManager.start_workspace(workspace)

  def stop(workspace) do
    with :ok <- stop_if_running("workspace-#{workspace.slug}"),
         :ok <- stop_if_running("workspace-db-#{workspace.slug}") do
      {:ok, %{"status" => "stopped"}}
    end
  end

  def remove(workspace) do
    with :ok <- DockerClient.stop_and_remove("workspace-#{workspace.slug}"),
         :ok <- DockerClient.stop_and_remove("workspace-db-#{workspace.slug}") do
      {:ok, %{"files_preserved" => true}}
    end
  end

  def inspect_workspace(workspace) do
    {:ok,
     %{
       "status" =>
         if(DockerClient.running?("workspace-#{workspace.slug}"), do: "running", else: "stopped")
     }}
  end

  def files(workspace, :list, _) do
    with {:ok, files} <- WorkspaceManager.list_files(workspace.slug),
         do: {:ok, %{"files" => files}}
  end

  def files(workspace, :read, %{path: path}) do
    with {:ok, size} <-
           DockerClient.get_file_stat("workspace-#{workspace.slug}", @root <> "/" <> path),
         true <- size <= 2 * 1024 * 1024 or {:error, :too_large},
         {:ok, contents} <-
           DockerClient.read_file("workspace-#{workspace.slug}", @root <> "/" <> path),
         true <- String.valid?(contents) or {:error, :not_utf8} do
      {:ok, %{"contents" => contents}}
    end
  end

  def files(workspace, :write, %{path: path, content: content}) do
    with :ok <-
           DockerClient.write_file("workspace-#{workspace.slug}", @root <> "/" <> path, content),
         do: {:ok, %{"status" => "ok"}}
  end

  defp stop_if_running(name),
    do: if(DockerClient.running?(name), do: DockerClient.stop(name), else: :ok)
end
