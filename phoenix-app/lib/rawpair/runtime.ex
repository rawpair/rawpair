defmodule RawPair.Runtime do
  def backend(%{backend: :host}), do: RawPair.Runtime.Orqos
  def backend(%{backend: :docker}), do: RawPair.Runtime.Docker
  def configure(workspace), do: backend(workspace).configure(workspace)
  def start(workspace), do: backend(workspace).start(workspace)
  def stop(workspace), do: backend(workspace).stop(workspace)
  def remove(workspace), do: backend(workspace).remove(workspace)
  def inspect_workspace(workspace), do: backend(workspace).inspect_workspace(workspace)

  def files(workspace, operation, attrs \\ %{}) do
    path = Map.get(attrs, :path, "placeholder")

    if valid_path?(path) and byte_size(Map.get(attrs, :content, "")) <= 2 * 1024 * 1024,
      do: backend(workspace).files(workspace, operation, attrs),
      else: {:error, "Invalid relative file path or content too large"}
  end

  def valid_path?(path) when is_binary(path) do
    byte_size(path) in 1..4096 and not String.starts_with?(path, "/") and
      not String.contains?(path, <<0>>) and
      Enum.all?(String.split(path, "/"), &(&1 not in ["", ".", ".."]))
  end

  def valid_path?(_), do: false

  def terminal_path(%{backend: :host, runtime_id: id}), do: "/terminal/#{id}/"
  def terminal_path(workspace), do: "/terminal/docker-#{workspace.id}/"
end
