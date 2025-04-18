defmodule RawPair.Repo.Migrations.AddResourceLimitsToWorkspaces do
  use Ecto.Migration

  def change do
    alter table(:workspaces) do
      add :cpu_limit, :string
      add :mem_limit, :string
      add :mem_swap, :string
    end
  end
end
