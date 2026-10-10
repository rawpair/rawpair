defmodule RawPair.Runtime.Orqos do
  @behaviour RawPair.Runtime.Backend

  def request(method, path, body \\ nil) do
    base = Application.fetch_env!(:rawpair, :orqos_url)
    token = Application.fetch_env!(:rawpair, :orqos_token)
    headers = [{"authorization", "Bearer " <> token}, {"content-type", "application/json"}]
    encoded = if body, do: Jason.encode!(body), else: nil

    with {:ok, response} <-
           Finch.build(method, base <> path, headers, encoded)
           |> Finch.request(RawPair.Finch, receive_timeout: 180_000),
         {:ok, data} <- Jason.decode(response.body) do
      if response.status in 200..299,
        do: {:ok, data},
        else: {:error, Map.get(data, "error", "Orqos HTTP #{response.status}")}
    else
      {:error, error} -> {:error, error}
    end
  end

  def probe(workspace, application) do
    base = Application.fetch_env!(:rawpair, :orqos_url)
    token = Application.fetch_env!(:rawpair, :orqos_token)
    path = "/host/workspaces/#{workspace.runtime_id}/applications/#{application.name}/proxy/"

    case Finch.build(:get, base <> path, [{"authorization", "Bearer " <> token}])
         |> Finch.request(RawPair.Finch, receive_timeout: 10_000) do
      {:ok, %{status: code}} when code not in [502, 503] -> {:ok, code}
      {:ok, %{status: code}} -> {:error, "HTTP #{code}"}
      {:error, error} -> {:error, error}
    end
  end

  def inventory, do: request(:get, "/host/inventory")

  def action(workspace, operation, attrs \\ %{}),
    do:
      request(
        :post,
        "/host/workspaces/#{workspace.runtime_id}/actions",
        Map.put(attrs, :operation, operation)
      )

  def configure(workspace),
    do: action(workspace, "configure", %{slot: workspace.host_slot, limits: limits(workspace)})

  def start(workspace) do
    case inspect_workspace(workspace) do
      {:ok, %{"status" => state}} when state in ["stopped", "failed"] ->
        with {:ok, _} <- configure(workspace), do: action(workspace, "start")

      {:error, "Workspace is not registered"} ->
        with {:ok, _} <- configure(workspace), do: action(workspace, "start")

      {:ok, _} ->
        action(workspace, "start")

      error ->
        error
    end
  end

  def stop(workspace) do
    case action(workspace, "stop") do
      {:error, "Workspace is not registered"} -> {:ok, %{"status" => "stopped"}}
      result -> result
    end
  end

  def remove(workspace) do
    case action(workspace, "remove") do
      {:error, "Workspace is not registered"} -> {:ok, %{"files_preserved" => true}}
      result -> result
    end
  end

  def inspect_workspace(workspace), do: request(:get, "/host/workspaces/#{workspace.runtime_id}")
  def files(workspace, :list, _), do: action(workspace, "list-files")
  def files(workspace, :read, attrs), do: action(workspace, "read-file", attrs)
  def files(workspace, :write, attrs), do: action(workspace, "write-file", attrs)

  def delete_files(workspace, confirmation),
    do: action(workspace, "delete-files", %{confirmation: confirmation})

  def put_application(workspace, application),
    do: action(workspace, "put-application", %{name: application.name, port: application.port})

  def remove_application(workspace, application),
    do: action(workspace, "remove-application", %{name: application.name})

  defp limits(workspace) do
    %{}
    |> maybe(
      :cpu_percent,
      if(workspace.cpu_limit, do: round(String.to_float(decimal(workspace.cpu_limit)) * 100))
    )
    |> maybe(:memory_mb, memory(workspace.mem_limit))
    |> maybe(:tasks, workspace.tasks_limit)
  end

  defp maybe(map, _, nil), do: map
  defp maybe(map, key, value), do: Map.put(map, key, value)
  defp decimal(value), do: if(String.contains?(value, "."), do: value, else: value <> ".0")
  defp memory(nil), do: nil

  defp memory(value) do
    {number, unit} = Float.parse(String.downcase(value))
    round(number * if(unit == "g", do: 1024, else: 1))
  end
end
