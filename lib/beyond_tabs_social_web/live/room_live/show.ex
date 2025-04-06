defmodule BeyondTabsSocialWeb.RoomLive.Show do
  use BeyondTabsSocialWeb, :live_view
  alias BeyondTabsSocial.Chat

  @impl true
  def mount(%{"slug" => slug} = params, _session, socket) do
    username = Map.get(params, "user", "Guest")

    messages = Chat.subscribe_to_room(slug)

    {:ok,
     socket
     |> assign(:slug, slug)
     |> assign(:page_title, "Room: #{slug}")
     |> assign(:user, username)
     |> assign(:messages, messages)}
  end

  @impl true
  def handle_event("send_message", %{"message" => content}, socket) do
    Chat.broadcast_message(socket.assigns.slug, socket.assigns.user, content)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_message, msg}, socket) do
    messages = [msg | socket.assigns.messages] |> Enum.take(100)
    {:noreply, assign(socket, :messages, messages)}
  end
end
