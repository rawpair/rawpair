# SPDX-License-Identifier: MPL-2.0

defmodule RawPair.Docker.WorkspaceManager do
  alias RawPair.Workspaces
  alias RawPair.Workspaces.Workspace
  alias RawPair.Repo

  @docker_network "rawpair"

  @app_dir "/home/devuser/app"

  @default_cpu "2.5"
  @default_mem "2.5g"
  @default_swap "4g"

  def effective_cpu(%Workspace{cpu_limit: nil}), do: @default_cpu
  def effective_cpu(%Workspace{cpu_limit: val}), do: val

  def effective_mem(%Workspace{mem_limit: nil}), do: @default_mem
  def effective_mem(%Workspace{mem_limit: val}), do: val

  def effective_swap(%Workspace{mem_swap: nil}), do: @default_swap
  def effective_swap(%Workspace{mem_swap: val}), do: val

  def default_cpu, do: @default_cpu
  def default_mem, do: @default_mem
  def default_swap, do: @default_swap


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
    with :ok <- RawPair.DockerClient.stop_and_remove(container_name),
      :ok <- RawPair.DockerClient.launch(%{
        image: workspace.docker_image,
        volume: "#{container_name}_volume",
        container_name: container_name,
        devices: workspace.devices,
        network: @docker_network,
        cpu: effective_cpu(workspace),
        memory: effective_mem(workspace),
        swap: effective_swap(workspace),
        slug: workspace.slug,
        target: @app_dir
      }) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_launch_db(%Workspace{with_db: :none}, _), do: :ok

  defp maybe_launch_db(%Workspace{} = workspace, db_container_name) do
    {image, internal_port, env} =
      case workspace.with_db do
        :postgres -> {"postgres:15", 5432, ["POSTGRES_PASSWORD=postgres"]}
        :mysql    -> {"mysql:8",     3306, ["MYSQL_ROOT_PASSWORD=mysql"]}
        :mariadb  -> {"mariadb:10",  3306, ["MARIADB_ROOT_PASSWORD=mariadb"]}
      end

    with :ok <- RawPair.DockerClient.stop_and_remove(db_container_name),
      :ok <-RawPair.DockerClient.launch_db(%{
        container_name: db_container_name,
        image: image,
        env: env,
        container_port: internal_port,
        host_port: workspace.postgres_port,
        network: @docker_network,
        slug: "#{workspace.slug}_db",
      }) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp running?(name) do
    RawPair.DockerClient.running?(name)
  end

  defp update_status(workspace, status) do
    Workspaces.update_workspace(workspace, %{status: status})
  end

  def list_files(slug) do
    container = "workspace-#{slug}"

    base_dir = "/home/devuser/app"

    cmd = [
      "docker", "exec", container,
      "find", base_dir,
      "-type", "f",
      "-not", "-path", "*/node_modules/*",
      "-not", "-path", "*/.git/*",
      "-not", "-path", "*/*.swp"
    ]

    case System.cmd(Enum.at(cmd, 0), Enum.drop(cmd, 1), stderr_to_stdout: true) do
      {output, 0} ->
        files =
          output
          |> String.trim()
          |> String.split("\n")
          |> Enum.map(&String.replace_prefix(&1, base_dir <> "/", ""))

        {:ok, files}

      {error_output, _exit_code} ->
        {:error, error_output}
    end
  end

end
