defmodule RawPair.Workspaces.Application do
  use Ecto.Schema
  import Ecto.Changeset

  schema "workspace_applications" do
    belongs_to :workspace, RawPair.Workspaces.Workspace
    field :name, :string
    field :port, :integer
    field :public, :boolean, default: false
    field :hostname_id, :string
    timestamps(type: :utc_datetime)
  end

  def changeset(app, attrs) do
    app
    |> cast(attrs, [:name, :port, :public])
    |> validate_required([:name, :port])
    |> validate_format(:name, ~r/^[a-z][a-z0-9-]{0,31}$/)
    |> validate_number(:port, greater_than_or_equal_to: 1024, less_than_or_equal_to: 65535)
    |> unique_constraint([:workspace_id, :name])
  end
end
