# SPDX-License-Identifier: MPL-2.0

defmodule RawPair.DockerClient do
  @moduledoc false
  @docker_api_version "v1.41"
  @sock "/var/run/docker.sock"

  def running?(container_name) do
    query =
      URI.encode_query(%{
        "filters" => Jason.encode!(%{"name" => [container_name]})
      })

    url = "http://docker/#{@docker_api_version}/containers/json?" <> query

    Finch.build(:get, url, [{"host", "docker"}], nil, unix_socket: @sock)
    |> Finch.request(RawPair.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, containers} when is_list(containers) -> containers != []
          _ -> false
        end

      _ -> false
    end
  end


  def list_containers(opts \\ []) do
    query =
      %{
        "filters" =>
          %{
            label: opts[:label] || [],
            status: opts[:status] || []
          }
          |> Enum.reject(fn {_k, v} -> v == [] end)
          |> Map.new()
          |> Jason.encode!(),
        "all" => if(opts[:all], do: "true", else: "false")
      }
      |> URI.encode_query()

    url = "http://docker/#{@docker_api_version}/containers/json?" <> query

    Finch.build(:get, url, [{"host", "docker"}], nil, unix_socket: @sock)
    |> Finch.request(RawPair.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        Jason.decode(body)

      {:ok, %Finch.Response{status: code, body: body}} ->
        {:error, {:http_error, code, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def launch(launch_spec) when is_map(launch_spec) do
    image = launch_spec[:image]
    volume = launch_spec[:volume]
    container_name = launch_spec[:container_name]
    devices = launch_spec[:devices]
    network = launch_spec[:network]
    cpu = parse_float(launch_spec[:cpu])
    memory = parse_bytes(launch_spec[:memory])
    swap = parse_bytes(launch_spec[:swap])
    slug = launch_spec[:slug]
    target = launch_spec[:target]

    body = %{
      "Image" => image,
      "Labels" => %{
        "rawpair.managed" => "true",
        "rawpair.workspace_slug" => slug
      },
      "HostConfig" => %{
        "Binds" => ["#{volume}:#{target}"],
        "Devices" =>
          devices
          |> Enum.filter(fn path ->
            if File.exists?(path), do: true, else: (Logger.warning("Skipping missing device: #{path}"); false)
          end)
          |> Enum.map(fn path ->
            %{
              "PathOnHost" => path,
              "PathInContainer" => path,
              "CgroupPermissions" => "rwm"
            }
          end),
        "NetworkMode" => network,
        "CpuQuota" => trunc(cpu * 100_000),
        "Memory" => memory,
        "MemorySwap" => swap
      }
    }

    query = URI.encode_query(%{"name" => container_name})

    with {:ok, %{"Id" => id}} <- post_json("/containers/create?#{query}", body),
         :ok <- post_empty("/containers/#{id}/start") do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def launch_db(launch_spec) when is_map(launch_spec) do
    image = launch_spec[:image]
    env = launch_spec[:env]
    host_port = launch_spec[:host_port]
    container_port = launch_spec[:container_port]
    container_name = launch_spec[:container_name]
    network = launch_spec[:network]
    slug = launch_spec[:slug]

    body = %{
      "Image" => image,
      "Labels" => %{
        "rawpair.managed" => "true",
        "rawpair.workspace_db_slug" => slug
      },
      "Env" => env,
      "ExposedPorts" => %{"#{container_port}/tcp" => %{}},
      "HostConfig" => %{
        "PortBindings" => %{"#{container_port}/tcp" => [%{"HostPort" => "#{host_port}"}]},
        "NetworkMode" => network
      }
    }

    query = URI.encode_query(%{"name" => container_name})

    with {:ok, %{"Id" => id}} <- post_json("/containers/create?#{query}", body),
        :ok <- post_empty("/containers/#{id}/start") do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end


  def stop_and_remove(name) do
    # Ignore non‐existent container errors (404) when stopping
    case post_empty("/containers/#{name}/stop") do
      :ok -> :ok
      {:error, {:http_error, 404, _}} -> :ok
      {:error, reason} -> {:error, {:stop_failed, reason}}
    end
    |> case do
      :ok ->
        # Ignore non‐existent container errors (404) when removing
        case delete("/containers/#{name}") do
          :ok -> :ok
          {:error, {:http_error, 404, _}} -> :ok
          {:error, reason} -> {:error, {:remove_failed, reason}}
        end
      error -> error
    end
  end

  def list_files(container_name, base_dir) do
    find_cmd = [
      "find", base_dir,
      "-type", "f",
      "-not", "-path", "*/node_modules/*",
      "-not", "-path", "*/.git/*",
      "-not", "-path", "*/*.swp"
    ]

    with {:ok, %{"Id" => exec_id}} <- create_exec(container_name, find_cmd),
        {:ok, output} <- start_exec(exec_id),
        {:ok, %{"ExitCode" => 0}} <- exec_inspect(exec_id) do

      files =
        output
        |> String.trim()
        |> String.split("\n")
        |> Enum.map(&String.replace_prefix(&1, base_dir <> "/", ""))

      {:ok, files}

    else
      {:ok, %{"ExitCode" => code}} -> {:error, "Command failed with exit code #{code}"}
      {:error, reason} -> {:error, reason}
    end

  end

  defp create_exec(container, cmd) do
    body = %{
      "AttachStdout" => true,
      "AttachStderr" => true,
      "Cmd" => cmd
    }

    url = "http://docker/#{@docker_api_version}/containers/#{container}/exec"

    Finch.build(:post, url, [{"Content-Type", "application/json"}, {"host", "docker"}], Jason.encode!(body), unix_socket: @sock)
    |> Finch.request(RawPair.Finch)
    |> case do
      {:ok, %Finch.Response{status: 201, body: body}} -> Jason.decode(body)
      {:ok, %Finch.Response{status: code, body: body}} -> {:error, {:http_error, code, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp start_exec(exec_id) do
    body = %{"Detach" => false, "Tty" => false}
    url = "http://docker/v1.41/exec/#{exec_id}/start"

    Finch.build(:post, url, [{"Content-Type", "application/json"}, {"host", "docker"}], Jason.encode!(body), unix_socket: "/var/run/docker.sock")
    |> Finch.request(RawPair.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: raw_output}} ->
        {:ok, strip_exec_stream(raw_output)}

      {:ok, %Finch.Response{status: code, body: body}} ->
        {:error, {:http_error, code, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp strip_exec_stream(data) do
    # Docker exec returns 8-byte framing per stream chunk
    # If it's just one frame, we can just trim the header
    if byte_size(data) > 8 do
      binary_part(data, 8, byte_size(data) - 8)
    else
      data
    end
  end


  defp exec_inspect(exec_id) do
    url = "http://docker/#{@docker_api_version}/exec/#{exec_id}/json"

    Finch.build(:get, url, [{"host", "docker"}], nil, unix_socket: @sock)
    |> Finch.request(RawPair.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        Jason.decode(body)

      {:ok, %Finch.Response{status: code, body: body}} ->
        {:error, {:http_error, code, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end


  defp post_json(path, data) do
    url = "http://docker/#{@docker_api_version}#{path}"

    Finch.build(:post, url, [{"Content-Type", "application/json"}, {"host", "docker"}], Jason.encode!(data), unix_socket: @sock)
    |> Finch.request(RawPair.Finch)
    |> case do
      {:ok, %Finch.Response{status: code, body: body}} when code in 200..299 -> Jason.decode(body)
      {:ok, %Finch.Response{status: code, body: body}} -> {:error, {:http_error, code, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp post_empty(path) do
    url = "http://docker/#{@docker_api_version}#{path}"

    Finch.build(:post, url, [{"host", "docker"}], nil, unix_socket: @sock)
    |> Finch.request(RawPair.Finch)
    |> case do
      {:ok, %Finch.Response{status: code}} when code in 204..299 -> :ok
      {:ok, %Finch.Response{status: code, body: body}} -> {:error, {:http_error, code, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp delete(path) do
    url = "http://docker/#{@docker_api_version}#{path}"

    Finch.build(:delete, url, [{"host", "docker"}], nil, unix_socket: @sock)
    |> Finch.request(RawPair.Finch)
    |> case do
      {:ok, %Finch.Response{status: code}} when code in 200..299 -> :ok
      {:ok, %Finch.Response{status: code, body: body}} -> {:error, {:http_error, code, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {n, _} -> n
      :error -> raise ArgumentError, "invalid float: #{inspect(val)}"
    end
  end

  defp parse_float(val) when is_number(val), do: val

  defp parse_bytes("0"), do: 0
  defp parse_bytes(val) when is_binary(val) do
    case Regex.run(~r/^(\d+(?:\.\d+)?)([kmgtp]?)(b?)$/i, val) do
      [_, number, unit, _] ->
        base = parse_float(number)

        multiplier =
          case String.downcase(unit) do
            "" -> 1
            "k" -> 1024
            "m" -> 1_048_576
            "g" -> 1_073_741_824
            "t" -> 1_099_511_627_776
            "p" -> 1_125_899_906_842_624
            _ -> raise ArgumentError, "unknown unit: #{unit}"
          end

        trunc(base * multiplier)

      _ -> raise ArgumentError, "invalid byte string: #{inspect(val)}"
    end
  end

  defp parse_bytes(val) when is_integer(val), do: val
end
