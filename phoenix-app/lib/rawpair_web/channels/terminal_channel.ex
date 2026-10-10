defmodule RawPairWeb.TerminalChannel do
  use RawPairWeb, :channel
  alias RawPair.{Workspaces, Accounts, TerminalBridge}

  def join("terminal:" <> slug, _, socket) do
    workspace = Workspaces.get_workspace_by_slug!(slug)

    if workspace.backend == :docker and
         Workspaces.permitted?(socket.assigns.current_user, workspace) do
      case TerminalBridge.start_link(workspace.slug) do
        {:ok, bridge} ->
          timer = :timer.send_interval(15_000, :check_access)
          {:ok, assign(socket, workspace: workspace, bridge: bridge, timer: timer)}

        {:error, _} ->
          {:error, %{reason: "Terminal unavailable"}}
      end
    else
      {:error, %{reason: "Use the authorized ttyd terminal gateway"}}
    end
  rescue
    Ecto.NoResultsError -> {:error, %{reason: "Workspace access denied"}}
  end

  def handle_info(:check_access, socket) do
    if Accounts.user_for_session(socket.assigns.session_token) &&
         Workspaces.permitted?(socket.assigns.current_user, socket.assigns.workspace),
       do: {:noreply, socket},
       else: {:stop, :normal, socket}
  end

  def terminate(_, socket) do
    if socket.assigns[:bridge] && Process.alive?(socket.assigns.bridge),
      do: GenServer.stop(socket.assigns.bridge)

    if match?({:ok, _}, socket.assigns[:timer]), do: :timer.cancel(elem(socket.assigns.timer, 1))
    :ok
  end

  def handle_in("input", %{"data" => data}, socket)
      when is_binary(data) and byte_size(data) <= 65536 do
    if Accounts.user_for_session(socket.assigns.session_token) &&
         Workspaces.permitted?(socket.assigns.current_user, socket.assigns.workspace) do
      TerminalBridge.send_input(socket.assigns.bridge, data)
      {:noreply, socket}
    else
      {:stop, :normal, socket}
    end
  end
end
