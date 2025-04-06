defmodule BeyondTabsSocialWeb.WorkspaceLive.Index do
  use BeyondTabsSocialWeb, :live_view

  alias BeyondTabsSocial.Workspaces
  alias BeyondTabsSocial.Workspaces.Workspace

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :workspaces, Workspaces.list_workspaces())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Workspace")
    |> assign(:workspace, Workspaces.get_workspace!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Workspace")
    |> assign(:workspace, %Workspace{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Workspaces")
    |> assign(:workspace, nil)
  end

  @impl true
  def handle_info({BeyondTabsSocialWeb.WorkspaceLive.FormComponent, {:saved, workspace}}, socket) do
    {:noreply, stream_insert(socket, :workspaces, workspace)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    workspace = Workspaces.get_workspace!(id)
    {:ok, _} = Workspaces.delete_workspace(workspace)

    {:noreply, stream_delete(socket, :workspaces, workspace)}
  end
end
