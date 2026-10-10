defmodule RawPairWeb.WorkspaceLive.Index do
  use RawPairWeb, :live_view
  alias RawPair.{Workspaces, Runtime}
  alias RawPair.Workspaces.Workspace

  def mount(_, _, socket) do
    if connected?(socket), do: :timer.send_interval(10_000, :refresh)
    default = Application.get_env(:rawpair, :backends, [:docker]) |> hd()

    {:ok,
     socket
     |> assign(
       form: to_form(Workspaces.change_workspace(%Workspace{backend: default})),
       slots: [],
       inventory_error: nil
     )
     |> refresh()}
  end

  def handle_params(%{"id" => id}, _, socket),
    do: {:noreply, push_navigate(socket, to: ~p"/workspaces/#{id}")}

  def handle_params(_, _, socket) do
    {slots, error} =
      if :host in Application.get_env(:rawpair, :backends, [:docker]) do
        case RawPair.Runtime.Orqos.inventory() do
          {:ok, %{"slots" => slots}} -> {slots, nil}
          {:error, error} -> {[], inspect(error)}
        end
      else
        {[], nil}
      end

    {:noreply, assign(socket, page_title: "Workspaces", slots: slots, inventory_error: error)}
  end

  def handle_info(:refresh, socket), do: {:noreply, refresh(socket)}

  def handle_event("validate", %{"workspace" => attrs}, socket) do
    default = hd(Application.get_env(:rawpair, :backends, [:docker]))

    {:noreply,
     assign(socket,
       form: to_form(Workspaces.change_workspace(%Workspace{backend: default}, attrs))
     )}
  end

  def handle_event("create", %{"workspace" => attrs}, socket) do
    case Workspaces.create_workspace(socket.assigns.current_user, attrs) do
      {:ok, workspace} -> {:noreply, push_navigate(socket, to: ~p"/workspaces/#{workspace}")}
      {:error, changeset} -> {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event(action, %{"id" => id}, socket) when action in ["start", "stop"] do
    workspace = Workspaces.get_authorized!(socket.assigns.current_user, id)
    operation = if action == "start", do: :start, else: :stop

    case Workspaces.transition(socket.assigns.current_user, workspace, operation) do
      {:ok, _} -> {:noreply, refresh(socket)}
      {:error, error} -> {:noreply, put_flash(socket, :error, inspect(error)) |> refresh()}
    end
  end

  defp refresh(socket) do
    rows =
      Workspaces.list_workspaces(socket.assigns.current_user)
      |> Enum.map(fn workspace ->
        observed =
          case Runtime.inspect_workspace(workspace) do
            {:ok, status} -> Map.get(status, "status", "unavailable")
            {:error, _} -> "unavailable"
          end

        %{workspace: workspace, observed: observed}
      end)

    assign(socket, rows: rows)
  end
end
