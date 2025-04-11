defmodule RawPairWeb.RoomLive.Show do
  use RawPairWeb, :live_view

  alias RawPair.Workspaces
  alias RawPair.Chat

  @impl true
  def mount(%{"slug" => slug} = params, session, socket) do
    username = session["username"]
    workspace = Workspaces.get_workspace_by_slug!(slug)
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
     |> assign(:username, username)
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
end
