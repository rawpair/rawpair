# SPDX-License-Identifier: MPL-2.0

defmodule RawPairWeb.WorkspaceLive.Index do
  use RawPairWeb, :live_view

  alias RawPair.Workspaces
  alias RawPair.Workspaces.Workspace

  @impl true
  def mount(_params, session, socket) do
    username = session["username"]

    socket =
      socket
      |> assign(:username, username)
      |> assign(:default_cpu, RawPair.Docker.WorkspaceManager.default_cpu())
      |> assign(:default_mem, RawPair.Docker.WorkspaceManager.default_mem())
      |> assign(:default_swap, RawPair.Docker.WorkspaceManager.default_swap())
      |> stream(:workspaces, Workspaces.list_workspaces())

    {:ok, socket}
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

  @impl true
  def handle_event("launch", %{"id" => id}, socket) do
    workspace = Workspaces.get_workspace!(id)

    case RawPair.Docker.WorkspaceManager.start_workspace(workspace) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Workspace launched!")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to launch: #{inspect(reason)}")}
    end
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
  def handle_info({RawPairWeb.WorkspaceLive.FormComponent, {:saved, workspace}}, socket) do
    {:noreply, stream_insert(socket, :workspaces, workspace)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    workspace = Workspaces.get_workspace!(id)
    {:ok, _} = Workspaces.delete_workspace(workspace)

    {:noreply, stream_delete(socket, :workspaces, workspace)}
  end
end
