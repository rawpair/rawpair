defmodule RawPairWeb.RoomLive.Show do
  use RawPairWeb, :live_view

  alias RawPair.Workspaces
  alias RawPair.Chat

  @impl true
  def mount(%{"slug" => slug} = params, _session, socket) do
    workspace = Workspaces.get_workspace_by_slug!(slug)
    username = Map.get(params, "user", random_username())
    topic = "room:#{slug}"
    messages = Chat.get_history(slug) |> Enum.reverse()
    Phoenix.PubSub.subscribe(RawPair.PubSub, topic)

    terminal_base_url = RawPair.Env.terminal_base_url()

    {:ok,
     socket
     |> assign(:slug, slug)
     |> assign(:user, username)
     |> assign(:page_title, "Room: #{slug}")
     |> assign(:topic, topic)
     |> assign(:terminal_base_url, terminal_base_url)
     |> assign(:messages, messages)
     |> assign(:workspace, workspace)}
  end

  @impl true
  def handle_event("send_message", %{"message" => content}, socket) do
    Chat.broadcast_message(socket.assigns.slug, socket.assigns.user, content)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_message, msg}, socket) do
    messages =
      socket.assigns.messages
      |> Enum.concat([msg])
      |> Enum.take(-100)

    {:noreply, assign(socket, :messages, messages)}
  end

  defp random_username do
    "guest_" <> :crypto.strong_rand_bytes(2) |> Base.url_encode64 |> binary_part(0, 4)
  end
end
