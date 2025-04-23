# SPDX-License-Identifier: MPL-2.0

defmodule RawPair.Monitoring do
  def list_rawpair_containers do
    with {:ok, containers} <- RawPair.DockerClient.list_containers(label: ["rawpair.managed=true"]) do
      containers
      |> Enum.map(fn %{
        "Id" => id,
        "Image" => image,
        "Names" => [name | _],
        "Status" => status
      } ->
        %{id: id, image: image, name: String.trim_leading(name, "/"), status: status}
      end)
    else
      {:error, reason} ->
        # Optional: log or fallback
        IO.inspect(reason, label: "Failed to list containers")
        []
    end
  end
end
