defmodule RawPair.Applications do
  import Ecto.Query
  alias RawPair.{Repo, Workspaces}
  alias RawPair.Workspaces.Application, as: App
  alias RawPair.Runtime.Orqos

  def list(workspace),
    do: Repo.all(from a in App, where: a.workspace_id == ^workspace.id, order_by: a.name)

  def get!(workspace, id),
    do: Repo.one!(from a in App, where: a.workspace_id == ^workspace.id and a.id == ^id)

  def host(app), do: "a-#{app.hostname_id}." <> Application.fetch_env!(:rawpair, :preview_domain)
  def url(app), do: "https://" <> host(app) <> "/"

  def from_host(host) when is_binary(host) do
    domain = Regex.escape(Application.fetch_env!(:rawpair, :preview_domain))

    case Regex.run(~r/^a-([0-9a-f]{24})\.#{domain}$/, String.downcase(host)) do
      [_, id] -> Repo.get_by(App, hostname_id: id) |> Repo.preload(:workspace)
      _ -> nil
    end
  end

  def from_host(_), do: nil

  def put(user, workspace, attrs) do
    Workspaces.authorize!(user, workspace, :owner)

    if workspace.backend != :host do
      {:error, "Named previews require a native workspace"}
    else
      app = %App{
        workspace_id: workspace.id,
        hostname_id: Base.encode16(:crypto.strong_rand_bytes(12), case: :lower)
      }

      changeset = App.changeset(app, attrs)

      Repo.transaction(fn ->
        saved =
          case Repo.insert(changeset) do
            {:ok, app} -> app
            {:error, changeset} -> Repo.rollback(changeset)
          end

        case Orqos.put_application(workspace, saved) do
          {:ok, _} -> saved
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
    end
  end

  def visibility(user, workspace, app, public) do
    Workspaces.authorize!(user, workspace, :owner)
    app |> App.changeset(%{public: public}) |> Repo.update()
  end

  def remove(user, workspace, app) do
    Workspaces.authorize!(user, workspace, :owner)
    with {:ok, _} <- Orqos.remove_application(workspace, app), do: Repo.delete(app)
  end
end
