defmodule RawPairWeb.WorkspaceControllerTest do
  use RawPairWeb.ConnCase
  import RawPair.NativeFixtures
  alias RawPair.Accounts

  setup %{conn: conn} do
    owner = user()
    %{conn: init_test_session(conn, session_token: Accounts.create_session(owner))}
  end

  test "workspace routes dispatch to their own handlers", %{conn: conn} do
    assert %{"workspaces" => []} = get(conn, "/api/workspaces") |> json_response(200)

    invalid =
      post(conn, "/api/workspaces", %{
        "workspace" => %{"name" => "", "slug" => "", "backend" => "host"}
      })
      |> json_response(422)

    assert invalid["error"] =~ "name"
    refute invalid["error"] == "Use start or stop"
  end

  test "workspace transitions retain their public route and input validation", %{conn: conn} do
    assert %{"error" => "Use start or stop"} =
             post(conn, "/api/workspaces/unused/actions", %{"operation" => "unknown"})
             |> json_response(422)
  end
end
