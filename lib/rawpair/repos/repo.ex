defmodule RawPair.Repos.Repo do
  use Ecto.Schema
  import Ecto.Changeset

  schema "repo_repos" do
    field :name, :string
    field :owner, :string
    field :description, :string
    field :url, :string
    field :github_id, :integer
    field :primary_language, :string
    field :stars, :integer
    field :last_synced_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(repo, attrs) do
    repo
    |> cast(attrs, [:name, :owner, :github_id, :description, :primary_language, :stars, :url, :last_synced_at])
    |> validate_required([:name, :owner, :github_id, :description, :primary_language, :stars, :url, :last_synced_at])
  end
end
