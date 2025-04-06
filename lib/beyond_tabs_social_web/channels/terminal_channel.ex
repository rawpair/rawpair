defmodule BeyondTabsSocialWeb.TerminalChannel do
  use BeyondTabsSocialWeb, :channel

  alias BeyondTabsSocial.TerminalBridge

  def join("terminal:" <> slug, _params, socket) do
    {:ok, pid} = TerminalBridge.start_link(slug)
    {:ok, assign(socket, :bridge, pid)}
  end

  def handle_in("input", %{"data" => char}, socket) do
    TerminalBridge.send_input(socket.assigns.bridge, char)
    {:noreply, socket}
  end
end
