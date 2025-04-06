defmodule BeyondTabsSocial.Repo.Migrations.CreateWorkspaces do
  use Ecto.Migration

  def change do
    create table(:workspaces) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :docker_image, :string, null: false
      add :with_postgres, :boolean, default: false
      add :workspace_port, :integer
      add :postgres_port, :integer
      add :status, :string, null: false, default: "pending"
      add :last_active_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:workspaces, [:slug])
  end
end
