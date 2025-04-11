# SPDX-License-Identifier: MPL-2.0

defmodule RawPairWeb.TerminalChannel do
  use RawPairWeb, :channel

  alias RawPair.TerminalBridge

  def join("terminal:" <> slug, _params, socket) do
    session_id = socket.assigns.session_id
    container = "#{slug}"

    {:ok, pid} = TerminalBridge.start_link(container)

    {:ok,
     socket
     |> assign(:container, container)
     |> assign(:bridge, pid)}
  end

  def handle_in("input", %{"data" => char}, socket) do
    TerminalBridge.send_input(socket.assigns.bridge, char)
    {:noreply, socket}
  end


end
