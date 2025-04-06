defmodule BeyondTabsSocial.Repo.Migrations.AddUniqueIndexToRepoGithubId do
  use Ecto.Migration

  def change do
    create unique_index(:repo_repos, [:github_id])
  end
end
