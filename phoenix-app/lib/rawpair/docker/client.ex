# SPDX-License-Identifier: MPL-2.0

defmodule RawPair.DockerClient do
  @moduledoc false
  @docker_api_version "v1.41"
  @sock "/var/run/docker.sock"

  # ------------------------------------------------------------------
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
        "Devices" => Enum.map(devices, fn path ->
          %{"PathOnHost" => path, "PathInContainer" => path, "CgroupPermissions" => "rwm"}
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
