defmodule BeyondTabsSocial.Docker.WorkspaceManager do
  alias BeyondTabsSocial.Workspaces
  alias BeyondTabsSocial.Workspaces.Workspace
  alias BeyondTabsSocial.Repo

  @docker_network "beyond_tabs_net"


  def start_workspace(%Workspace{} = workspace) do
    # generate container name
    container_name = "workspace-#{workspace.slug}"
    db_container_name = "workspace-db-#{workspace.slug}"

    # check if already running
    if running?(container_name) do
      {:ok, workspace}
    else
      with {:ok, workspace} <- assign_ports(workspace),
           :ok <- launch_container(workspace, container_name),
           :ok <- maybe_launch_db(workspace, db_container_name) do
        update_status(workspace, :running)
      end
    end
  end

  defp assign_ports(workspace) do
    # Simplified static port assignment for now
    workspace_port = Enum.random(6000..6999)
    db_port = if workspace.with_db != :none, do: Enum.random(7000..7999), else: nil

    workspace
    |> Workspaces.update_workspace(%{
      workspace_port: workspace_port,
      postgres_port: db_port,
      status: :starting
    })
  end

  defp remove_existing_container(name) do
    {_out, 0} = System.cmd("docker", ["rm", "-f", name], stderr_to_stdout: true)
    :ok
  rescue
    _ -> :ok
  end


  defp launch_container(workspace, container_name) do
    image = workspace.docker_image
    port = workspace.workspace_port

    cmd = [
      "docker", "run", "-d",
      "--name", container_name,
      "--network", @docker_network,
      "-p", "#{port}:4000",
      image,
      "tail", "-f", "/dev/null"
    ]

    :ok = remove_existing_container(container_name)

    run_cmd(cmd)
  end

  defp maybe_launch_db(%Workspace{with_db: :none}, _), do: :ok

  defp maybe_launch_db(%Workspace{} = workspace, db_container_name) do
    {image, port} =
      case workspace.with_db do
        :postgres -> {"postgres:15", 5432}
        :mysql -> {"mysql:8", 3306}
        :mariadb -> {"mariadb:10", 3306}
      end

    host_port = workspace.postgres_port

    env =
      case workspace.with_db do
        :postgres -> ["-e", "POSTGRES_PASSWORD=postgres"]
        :mysql -> ["-e", "MYSQL_ROOT_PASSWORD=mysql"]
        :mariadb -> ["-e", "MARIADB_ROOT_PASSWORD=mariadb"]
      end

    cmd = [
      "docker", "run", "-d",
      "--name", db_container_name,
      "--network", @docker_network,
      "-p", "#{host_port}:#{port}"
    ] ++ env ++ [image]

    :ok = remove_existing_container(db_container_name)

    run_cmd(cmd)
  end

  defp run_cmd(cmd) do
    case System.cmd(List.first(cmd), Enum.drop(cmd, 1), stderr_to_stdout: true) do
      {output, 0} -> :ok
      {output, _} -> {:error, output}
    end
  end

  defp running?(name) do
    {output, 0} = System.cmd("docker", ["ps", "-q", "-f", "name=#{name}"])
    output != ""
  end

  defp update_status(workspace, status) do
    Workspaces.update_workspace(workspace, %{status: status})
  end
end
