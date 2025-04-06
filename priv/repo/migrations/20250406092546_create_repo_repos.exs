defmodule BeyondTabsSocial.Repo.Migrations.CreateRepoRepos do
  use Ecto.Migration

  def change do
    create table(:repo_repos) do
      add :name, :string
      add :owner, :string
      add :github_id, :integer
      add :description, :text
      add :primary_language, :string
      add :stars, :integer
      add :url, :string
      add :last_synced_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end
  end
end
