# SPDX-License-Identifier: MPL-2.0

defmodule RawPair.Workspaces.Workspace do
  use Ecto.Schema
  import Ecto.Changeset

  @device_regex ~r|^/dev/[a-zA-Z0-9._/-]+(:/dev/[a-zA-Z0-9._/-]+)?$|

  schema "workspaces" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :docker_image, :string
    field :with_db, Ecto.Enum, values: [:none, :postgres, :mysql, :mariadb], default: :none
    field :workspace_port, :integer
    field :postgres_port, :integer
    field :devices, {:array, :string}, default: []
    field :cpu_limit, :string
    field :mem_limit, :string
    field :mem_swap, :string
    field :status, Ecto.Enum, values: [:pending, :starting, :running, :stopped, :failed], default: :pending
    field :last_active_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(workspace, attrs) do
    workspace
    |> cast(attrs, [
      :name,
      :slug,
      :description,
      :docker_image,
      :with_db,
      :workspace_port,
      :postgres_port,
      :status,
      :last_active_at,
      :devices,
      :cpu_limit,
      :mem_limit,
      :mem_swap
    ])
    |> maybe_generate_slug()
    |> validate_required([:name, :docker_image])
    |> unique_constraint(:slug)
    |> validate_devices()
    |> validate_format(:cpu_limit, ~r/^\d+(\.\d+)?$/, message: "Invalid CPU format")
    |> validate_format(:mem_limit, ~r/^\d+(\.\d+)?[gm]$/i, message: "Invalid memory format")
    |> validate_format(:mem_swap, ~r/^\d+(\.\d+)?[gm]$/i, message: "Invalid swap format")
  end

  defp maybe_generate_slug(changeset) do
    case get_field(changeset, :slug) do
      nil ->
        if name = get_field(changeset, :name) do
          put_change(changeset, :slug, Slug.slugify(name))
        else
          changeset
        end

      _ -> changeset
    end
  end

  defp validate_devices(changeset) do
    validate_change(changeset, :devices, fn :devices, devices ->
      Enum.flat_map(devices, fn dev ->
        if String.match?(dev, @device_regex), do: [], else: [devices: "invalid device path"]
      end)
    end)
  end
end
