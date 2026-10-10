defmodule RawPairWeb.TerminalChannelTest do
  use RawPairWeb.ChannelCase
  import RawPair.NativeFixtures
  alias RawPair.Accounts

  test "anonymous sockets and forged session parameters are refused" do
    assert :error =
             connect(RawPairWeb.UserSocket, %{"username" => "operator"},
               connect_info: %{session: %{}}
             )
  end

  test "host terminals cannot bypass the authorized ttyd gateway" do
    account = user()
    project = workspace(account)

    {:ok, socket} =
      connect(RawPairWeb.UserSocket, %{},
        connect_info: %{session: %{"session_token" => Accounts.create_session(account)}}
      )

    assert {:error, %{reason: "Use the authorized ttyd terminal gateway"}} =
             subscribe_and_join(socket, RawPairWeb.TerminalChannel, "terminal:#{project.slug}")
  end
end
