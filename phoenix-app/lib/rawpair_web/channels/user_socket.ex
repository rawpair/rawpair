defmodule RawPairWeb.UserSocket do
  use Phoenix.Socket
  channel "terminal:*", RawPairWeb.TerminalChannel

  def connect(_params, socket, %{session: session}) when is_map(session) do
    token = session["session_token"]

    case RawPair.Accounts.user_for_session(token) do
      nil -> :error
      user -> {:ok, assign(socket, current_user: user, session_token: token)}
    end
  end

  def connect(_, _, _), do: :error
  def id(socket), do: "session:#{RawPair.Accounts.hash(socket.assigns.session_token)}"
end
