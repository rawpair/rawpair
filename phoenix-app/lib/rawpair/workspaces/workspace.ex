defmodule RawPair.Workspaces.Workspace do
  use Ecto.Schema
  import Ecto.Changeset

  schema "workspaces" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :docker_image, :string
    field :with_db, Ecto.Enum, values: [:none, :postgres, :mysql, :mariadb], default: :none
    field :workspace_port, :integer
    field :postgres_port, :integer
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
      :last_active_at
    ])
    |> maybe_generate_slug()
    |> validate_required([:name, :docker_image])
    |> unique_constraint(:slug)
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
end
