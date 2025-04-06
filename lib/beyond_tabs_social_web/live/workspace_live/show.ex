defmodule BeyondTabsSocialWeb.WorkspaceLive.Show do
  use BeyondTabsSocialWeb, :live_view

  alias BeyondTabsSocial.Workspaces

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
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
