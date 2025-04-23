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
end
