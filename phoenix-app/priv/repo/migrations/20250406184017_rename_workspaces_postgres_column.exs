defmodule RawPair.Repo.Migrations.RenameWithPostgresToWithDb do
  use Ecto.Migration

  def change do
    alter table(:workspaces) do
      remove :with_postgres
      add :with_db, :string, null: false, default: "none"
    end
  end
end
