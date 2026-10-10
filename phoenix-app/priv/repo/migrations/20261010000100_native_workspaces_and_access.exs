defmodule RawPair.Repo.Migrations.NativeWorkspacesAndAccess do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :username, :string, null: false
      add :password_hash, :string, null: false
      add :admin, :boolean, default: false, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:username])

    create table(:user_sessions, primary_key: false) do
      add :token_hash, :string, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :expires_at, :utc_datetime, null: false
    end

    create index(:user_sessions, [:user_id])

    alter table(:workspaces) do
      modify :docker_image, :string, null: true, from: {:string, null: false}
      add :backend, :string, default: "docker", null: false
      add :runtime_id, :string
      add :collaboration_version, :integer, null: false, default: 0
      add :host_slot, :string
      add :tasks_limit, :integer, default: 512
    end

    create unique_index(:workspaces, [:runtime_id])
    create unique_index(:workspaces, [:host_slot], where: "backend = 'host'")

    create table(:workspace_memberships) do
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "member"
    end

    create unique_index(:workspace_memberships, [:workspace_id, :user_id])

    create table(:workspace_applications) do
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :port, :integer, null: false
      add :public, :boolean, null: false, default: false
      add :hostname_id, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:workspace_applications, [:workspace_id, :name])
    create unique_index(:workspace_applications, [:hostname_id])

    create table(:preview_credentials, primary_key: false) do
      add :token_hash, :string, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :application_id, references(:workspace_applications, on_delete: :delete_all),
        null: false

      add :session_hash, :string, null: false
      add :kind, :string, null: false
      add :expires_at, :utc_datetime, null: false
    end

    create index(:preview_credentials, [:application_id])
  end
end
