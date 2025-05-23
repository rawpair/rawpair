# SPDX-License-Identifier: MPL-2.0

defmodule RawPairWeb.WorkspaceLive.Show do
  use RawPairWeb, :live_view

  alias RawPair.Workspaces

  @impl true
  def mount(_params, session, socket) do
    username = session["username"]
    {:ok, assign(socket, username: username)}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:workspace, Workspaces.get_workspace!(id))}
  end

  defp page_title(:show), do: "Show Workspace"
  defp page_title(:edit), do: "Edit Workspace"
end
