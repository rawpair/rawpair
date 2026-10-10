defmodule RawPairWeb.PageController do
  use RawPairWeb, :controller

  def home(conn, _params), do: render(conn, :home, layout: false)

  def enter(conn, %{"username" => username, "password" => password}) do
    case RawPair.Accounts.authenticate(String.trim(username), password) do
      {:ok, user} ->
        RawPair.Accounts.delete_session(get_session(conn, :session_token))
        preview_host = get_session(conn, :preview_login_host)

        destination =
          if preview_host, do: "/previews/" <> URI.encode(preview_host), else: "/workspaces"

        token = RawPair.Accounts.create_session(user)

        conn
        |> configure_session(renew: true)
        |> clear_session()
        |> put_session(:session_token, token)
        |> put_session(:live_socket_id, "session:#{RawPair.Accounts.hash(token)}")
        |> redirect(to: destination)

      {:error, _} ->
        conn |> put_flash(:error, "Invalid username or password.") |> redirect(to: ~p"/")
    end
  end

  def enter(conn, _),
    do: conn |> put_flash(:error, "Username and password are required.") |> redirect(to: ~p"/")

  def logout(conn, _params) do
    RawPair.Accounts.delete_session(get_session(conn, :session_token))
    conn |> configure_session(drop: true) |> redirect(to: ~p"/")
  end
end
