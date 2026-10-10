defmodule RawPairWeb.Auth do
  import Plug.Conn
  import Phoenix.Controller
  alias RawPair.Accounts

  def init(opts), do: opts

  def call(conn, _) do
    assign(conn, :current_user, Accounts.user_for_session(get_session(conn, :session_token)))
  end

  def require_user(conn, _) do
    if conn.assigns[:current_user] do
      conn
    else
      conn |> redirect(to: "/") |> halt()
    end
  end

  def on_mount(:user, _params, session, socket) do
    case Accounts.user_for_session(session["session_token"]) do
      nil ->
        {:halt, Phoenix.LiveView.redirect(socket, to: "/")}

      user ->
        socket =
          socket
          |> Phoenix.Component.assign(
            current_user: user,
            username: user.username,
            session_token: session["session_token"]
          )
          |> Phoenix.LiveView.attach_hook(:recheck_session, :handle_event, fn _event,
                                                                              _params,
                                                                              socket ->
            if Accounts.user_for_session(socket.assigns.session_token),
              do: {:cont, socket},
              else: {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
          end)

        {:cont, socket}
    end
  end
end
