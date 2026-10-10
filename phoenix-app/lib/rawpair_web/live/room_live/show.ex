defmodule RawPairWeb.RoomLive.Show do
  use RawPairWeb, :live_view
  alias RawPair.{Workspaces, Chat, Accounts}

  def mount(%{"slug" => slug}, _, socket) do
    workspace = Workspaces.by_slug_authorized!(socket.assigns.current_user, slug)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(RawPair.PubSub, "room:#{slug}")
      :timer.send_interval(15_000, :check_access)
    end

    {:ok,
     assign(socket,
       slug: slug,
       user: socket.assigns.current_user.username,
       page_title: workspace.name,
       workspace: workspace,
       terminal_path: RawPair.Runtime.terminal_path(workspace),
       messages: Enum.reverse(Chat.get_history(slug))
     )}
  end

  def handle_event("send_message", %{"message" => content}, socket) do
    Workspaces.authorize!(socket.assigns.current_user, socket.assigns.workspace)

    Chat.broadcast_message(
      socket.assigns.slug,
      socket.assigns.user,
      String.slice(content, 0, 4000)
    )

    {:noreply, socket}
  end

  def handle_info(:check_access, socket) do
    if Accounts.user_for_session(socket.assigns.session_token) &&
         Workspaces.permitted?(socket.assigns.current_user, socket.assigns.workspace),
       do: {:noreply, socket},
       else: {:noreply, push_navigate(socket, to: ~p"/workspaces")}
  end

  def handle_info({:new_message, msg}, socket) do
    if Workspaces.permitted?(socket.assigns.current_user, socket.assigns.workspace),
      do: {:noreply, assign(socket, messages: Enum.take(socket.assigns.messages ++ [msg], -100))},
      else: {:noreply, push_navigate(socket, to: ~p"/workspaces")}
  end
end
