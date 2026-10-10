defmodule RawPairWeb.WorkspaceLive.Show do
  use RawPairWeb, :live_view
  alias RawPair.{Workspaces, Runtime, Applications}

  def mount(_, _, socket) do
    if connected?(socket), do: :timer.send_interval(10_000, :refresh)
    {:ok, assign(socket, connection_status: %{})}
  end

  def handle_params(%{"id" => id}, _, socket) do
    workspace = Workspaces.get_authorized!(socket.assigns.current_user, id)
    {:noreply, socket |> assign(workspace: workspace, page_title: workspace.name) |> refresh()}
  end

  def handle_info(:refresh, socket), do: {:noreply, refresh(socket)}

  def handle_event(action, _, socket) when action in ["start", "stop"] do
    operation = if action == "start", do: :start, else: :stop

    result(
      socket,
      Workspaces.transition(socket.assigns.current_user, current(socket), operation),
      "Workspace #{action} completed"
    )
  end

  def handle_event("configure", %{"workspace" => attrs}, socket) do
    case Workspaces.configure(socket.assigns.current_user, current(socket), attrs) do
      {:ok, workspace} ->
        {:noreply,
         socket
         |> assign(workspace: workspace)
         |> put_flash(:info, "Configuration saved")
         |> refresh()}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("add_member", %{"username" => username, "role" => role}, socket) do
    result(
      socket,
      Workspaces.add_member(
        socket.assigns.current_user,
        current(socket),
        String.trim(username),
        role
      ),
      "Member added"
    )
  end

  def handle_event("remove_member", %{"id" => id}, socket) do
    result(
      socket,
      Workspaces.remove_member(socket.assigns.current_user, current(socket), id),
      "Member removed"
    )
  end

  def handle_event("add_application", %{"application" => attrs}, socket) do
    result(
      socket,
      Applications.put(socket.assigns.current_user, current(socket), attrs),
      "Application registered; start its server in the terminal"
    )
  end

  def handle_event("visibility", %{"id" => id, "public" => public}, socket) do
    workspace = current(socket)
    app = Applications.get!(workspace, id)

    result(
      socket,
      Applications.visibility(socket.assigns.current_user, workspace, app, public == "true"),
      "Visibility updated"
    )
  end

  def handle_event("remove_application", %{"id" => id}, socket) do
    workspace = current(socket)

    result(
      socket,
      Applications.remove(
        socket.assigns.current_user,
        workspace,
        Applications.get!(workspace, id)
      ),
      "Application route removed"
    )
  end

  def handle_event("check_application", %{"id" => id}, socket) do
    workspace = current(socket)
    app = Applications.get!(workspace, id)

    status =
      case RawPair.Runtime.Orqos.probe(workspace, app) do
        {:ok, code} -> "Responding (HTTP #{code})"
        {:error, reason} -> "Unavailable: #{inspect(reason)}"
      end

    {:noreply,
     assign(socket, connection_status: Map.put(socket.assigns.connection_status, app.id, status))}
  end

  def handle_event("delete_files", %{"confirmation" => confirmation}, socket) do
    result(
      socket,
      Workspaces.delete_files(socket.assigns.current_user, current(socket), confirmation),
      "Project contents deleted"
    )
  end

  def handle_event("remove", _, socket) do
    case Workspaces.remove(socket.assigns.current_user, current(socket)) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workspace removed. Project and home files remain in its slot.")
         |> push_navigate(to: ~p"/workspaces")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, inspect(error))}
    end
  end

  defp current(socket),
    do: Workspaces.get_authorized!(socket.assigns.current_user, socket.assigns.workspace.id)

  defp refresh(socket) do
    workspace = current(socket)

    observed =
      case Runtime.inspect_workspace(workspace) do
        {:ok, value} -> value
        {:error, error} -> %{"status" => "unavailable", "error" => inspect(error)}
      end

    assign(socket,
      workspace: workspace,
      observed: observed,
      owner: Workspaces.permitted?(socket.assigns.current_user, workspace, :owner),
      members: Workspaces.members(workspace),
      applications: Applications.list(workspace),
      form: to_form(Workspaces.change_workspace(workspace))
    )
  end

  defp result(socket, {:ok, _}, message),
    do: {:noreply, socket |> put_flash(:info, message) |> refresh()}

  defp result(socket, {:error, error}, _),
    do: {:noreply, put_flash(socket, :error, inspect(error))}
end
