defmodule RawPair.Repo.Migrations.AddDevicesToWorkspaces do
  use Ecto.Migration

  def change do
    alter table(:workspaces) do
      add :devices, {:array, :string}, default: []
    end
  end
end
