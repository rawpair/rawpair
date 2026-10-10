defmodule RawPairWeb.WorkspaceLiveTest do
  use RawPairWeb.ConnCase
  import Phoenix.LiveViewTest
  import RawPair.NativeFixtures
  alias RawPair.{Accounts, Workspaces, Repo}

  test "unauthenticated browsers cannot enter workspace views", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/workspaces")
  end

  test "list, room and management expose only explicitly joined workspaces", %{conn: conn} do
    owner = user()
    project = workspace(owner)
    stranger = user()
    other = workspace(stranger)
    conn = init_test_session(conn, session_token: Accounts.create_session(owner))
    {:ok, _, html} = live(conn, ~p"/workspaces")
    assert html =~ project.name
    refute html =~ other.name
    {:ok, _, html} = live(conn, ~p"/rooms/#{project.slug}")
    assert html =~ "data-terminal-path"
    {:ok, _, html} = live(conn, ~p"/workspaces/#{project.id}")
    assert html =~ "Remove workspace, preserve files"
    assert html =~ "Delete project contents"
    assert_raise Ecto.NoResultsError, fn -> Workspaces.get_authorized!(stranger, project.id) end
  end

  test "a member cannot publish applications, remove the workspace or manage membership" do
    owner = user()
    member = user()
    project = workspace(owner)
    assert {:ok, _} = Workspaces.add_member(owner, project, member.username, "member")
    assert Workspaces.permitted?(member, project)
    refute Workspaces.permitted?(member, project, :owner)
    assert_raise Ecto.NoResultsError, fn -> Workspaces.remove(member, project) end

    assert_raise Ecto.NoResultsError, fn ->
      Workspaces.add_member(member, project, owner.username, "owner")
    end

    assert {:error, "A workspace needs at least one owner"} =
             Workspaces.remove_member(owner, project, owner.id)

    assert {:error, "A workspace needs at least one owner"} =
             Workspaces.add_member(owner, project, owner.username, "member")

    assert {:ok, _} = Workspaces.add_member(owner, project, member.username, "owner")
    assert Workspaces.permitted?(member, project, :owner)
    assert Repo.get!(Workspaces.Workspace, project.id)
  end
end
