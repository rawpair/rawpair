defmodule RawPairWeb.PageControllerTest do
  use RawPairWeb.ConnCase
  import RawPair.NativeFixtures
  alias RawPair.Accounts

  test "login requires a verified password and creates a revocable session", %{conn: conn} do
    account = user()
    bad = post(conn, ~p"/enter", %{username: account.username, password: "wrong"})
    assert redirected_to(bad) == "/"
    refute get_session(bad, :session_token)

    good =
      post(recycle(conn), ~p"/enter", %{
        username: account.username,
        password: "a long test password"
      })

    assert redirected_to(good) == "/workspaces"
    token = get_session(good, :session_token)
    assert Accounts.user_for_session(token).id == account.id
    assert get_session(good, :live_socket_id) == "session:#{Accounts.hash(token)}"
    Accounts.delete_session(token)
    refute Accounts.user_for_session(token)
  end

  test "chosen username alone is not authentication", %{conn: conn} do
    response = post(conn, ~p"/enter", %{username: "operator"})
    assert redirected_to(response) == "/"
    refute get_session(response, :session_token)
  end
end
