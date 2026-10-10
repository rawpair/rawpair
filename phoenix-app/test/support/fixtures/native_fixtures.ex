defmodule RawPair.NativeFixtures do
  alias RawPair.{Accounts, Repo}
  alias RawPair.Workspaces.Workspace

  def user do
    {:ok, user} =
      Accounts.create_user("user_#{System.unique_integer([:positive])}", "a long test password")

    user
  end

  def workspace(user) do
    unique = System.unique_integer([:positive])

    workspace =
      Repo.insert!(%Workspace{
        name: "Project #{unique}",
        slug: "project-#{unique}",
        backend: :host,
        runtime_id: "ws-#{unique}",
        host_slot: "slot-#{unique}"
      })

    Repo.insert_all("workspace_memberships", [
      %{user_id: user.id, workspace_id: workspace.id, role: "owner"}
    ])

    workspace
  end
end
