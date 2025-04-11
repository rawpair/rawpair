# SPDX-License-Identifier: MPL-2.0

defmodule RawPair.Monitoring do
  def list_rawpair_containers do
    {output, 0} =
      System.cmd("docker", [
        "ps",
        "--filter", "label=rawpair.managed=true",
        "--format", "{{.ID}}|{{.Image}}|{{.Names}}|{{.Status}}"
      ])

    output
    |> String.trim()
    |> String.split("\n", trim: true)
    |> Enum.map(fn line ->
      [id, image, name, status] = String.split(line, "|")
      %{id: id, image: image, name: name, status: status}
    end)
  end
end
