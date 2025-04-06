defmodule BeyondTabsSocialWeb.RoomLive.Show do
  use BeyondTabsSocialWeb, :live_view

  alias BeyondTabsSocial.Chat

  @impl true
  def mount(%{"slug" => slug} = params, _session, socket) do
    username = Map.get(params, "user", random_username())
    topic = "room:#{slug}"
    messages = Chat.get_history(slug) |> Enum.reverse()
    Phoenix.PubSub.subscribe(BeyondTabsSocial.PubSub, topic)

    {:ok,
     socket
     |> assign(:slug, slug)
     |> assign(:user, username)
     |> assign(:page_title, "Room: #{slug}")
     |> assign(:topic, topic)
     |> assign(:messages, messages)}
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
