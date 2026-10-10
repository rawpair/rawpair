defmodule RawPairWeb.WorkspaceController do
  use RawPairWeb, :controller
  alias RawPair.{Workspaces, Applications, Runtime}

  def index(conn, _),
    do:
      json(conn, %{
        workspaces: Enum.map(Workspaces.list_workspaces(conn.assigns.current_user), &details/1)
      })

  def show(conn, %{"id" => id}), do: json(conn, details(authorized(conn, id)))

  def create(conn, %{"workspace" => attrs}),
    do: respond(conn, Workspaces.create_workspace(conn.assigns.current_user, attrs))

  def update(conn, %{"id" => id, "workspace" => attrs}),
    do:
      respond(conn, Workspaces.configure(conn.assigns.current_user, authorized(conn, id), attrs))

  def action(conn, %{"id" => id, "operation" => operation}) when operation in ["start", "stop"] do
    action = if operation == "start", do: :start, else: :stop
    respond(conn, Workspaces.transition(conn.assigns.current_user, authorized(conn, id), action))
  end

  def action(conn, _), do: conn |> put_status(422) |> json(%{error: "Use start or stop"})

  def remove(conn, %{"id" => id}) do
    case Workspaces.remove(conn.assigns.current_user, authorized(conn, id)) do
      {:ok, _} -> json(conn, %{removed: true, files_preserved: true})
      {:error, error} -> error(conn, error)
    end
  end

  def delete_files(conn, %{"id" => id, "confirmation" => confirmation}) do
    case Workspaces.delete_files(conn.assigns.current_user, authorized(conn, id), confirmation) do
      {:ok, data} -> json(conn, data)
      {:error, value} -> error(conn, value)
    end
  end

  def add_member(conn, %{"id" => id, "username" => username, "role" => role})
      when role in ["owner", "member"] do
    case Workspaces.add_member(conn.assigns.current_user, authorized(conn, id), username, role) do
      {:ok, _} -> json(conn, %{added: true})
      {:error, value} -> error(conn, value)
    end
  end

  def remove_member(conn, %{"id" => id, "user_id" => user_id}) do
    case Workspaces.remove_member(conn.assigns.current_user, authorized(conn, id), user_id) do
      {:ok, _} -> json(conn, %{removed: true})
      {:error, value} -> error(conn, value)
    end
  end

  def add_application(conn, %{"id" => id, "application" => attrs}) do
    case Applications.put(conn.assigns.current_user, authorized(conn, id), attrs) do
      {:ok, app} -> json(conn, %{id: app.id, url: Applications.url(app), public: app.public})
      {:error, value} -> error(conn, value)
    end
  end

  def visibility(conn, %{"id" => id, "application_id" => app_id, "public" => public})
      when is_boolean(public) do
    workspace = authorized(conn, id)

    case Applications.visibility(
           conn.assigns.current_user,
           workspace,
           Applications.get!(workspace, app_id),
           public
         ) do
      {:ok, app} -> json(conn, %{id: app.id, public: app.public})
      {:error, value} -> error(conn, value)
    end
  end

  def remove_application(conn, %{"id" => id, "application_id" => app_id}) do
    workspace = authorized(conn, id)

    case Applications.remove(
           conn.assigns.current_user,
           workspace,
           Applications.get!(workspace, app_id)
         ) do
      {:ok, _} -> json(conn, %{removed: true})
      {:error, value} -> error(conn, value)
    end
  end

  defp authorized(conn, id), do: Workspaces.get_authorized!(conn.assigns.current_user, id)

  defp details(workspace) do
    observed =
      case Runtime.inspect_workspace(workspace) do
        {:ok, data} -> data
        {:error, reason} -> %{status: "unavailable", error: inspect(reason)}
      end

    %{
      id: workspace.id,
      name: workspace.name,
      slug: workspace.slug,
      backend: workspace.backend,
      runtime_id: workspace.runtime_id,
      observed: observed,
      terminal: Runtime.terminal_path(workspace),
      applications:
        Enum.map(
          Applications.list(workspace),
          &%{
            id: &1.id,
            name: &1.name,
            port: &1.port,
            public: &1.public,
            url: Applications.url(&1)
          }
        )
    }
  end

  defp respond(conn, {:ok, workspace}), do: json(conn, details(workspace))
  defp respond(conn, {:error, value}), do: error(conn, value)

  defp error(conn, %Ecto.Changeset{} = changeset),
    do: conn |> put_status(422) |> json(%{error: inspect(changeset.errors)})

  defp error(conn, reason), do: conn |> put_status(422) |> json(%{error: inspect(reason)})
end
