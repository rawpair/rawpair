defmodule RawPairWeb.CollaborationController do
  use RawPairWeb, :controller
  alias RawPair.{Accounts, Workspaces, Runtime}

  def ticket(conn, %{"slug" => slug, "path" => path}) do
    workspace = Workspaces.by_slug_authorized!(conn.assigns.current_user, slug)

    if Runtime.valid_path?(path) do
      document =
        Jason.encode!([workspace.id, path, workspace.collaboration_version])
        |> Base.url_encode64(padding: false)

      ticket =
        Phoenix.Token.sign(RawPairWeb.Endpoint, "collaboration", %{
          session: Accounts.hash(get_session(conn, :session_token)),
          workspace: workspace.id,
          path: path,
          document: document,
          version: workspace.collaboration_version
        })

      json(conn, %{document: document, ticket: ticket})
    else
      conn |> put_status(422) |> json(%{error: "Invalid file path"})
    end
  end

  def reload(conn, %{"slug" => slug, "path" => path}) do
    workspace = Workspaces.by_slug_authorized!(conn.assigns.current_user, slug)

    with {:ok, %{"contents" => contents}} <- Runtime.files(workspace, :read, %{path: path}) do
      document =
        Jason.encode!([workspace.id, path, workspace.collaboration_version])
        |> Base.url_encode64(padding: false)

      url = Application.get_env(:rawpair, :collaboration_url, "http://127.0.0.1:1234")
      token = Application.fetch_env!(:rawpair, :collaboration_token)

      case Finch.build(
             :put,
             "#{url}/internal/documents/#{document}",
             [{"authorization", "Bearer " <> token}, {"content-type", "application/json"}],
             Jason.encode!(%{contents: contents})
           )
           |> Finch.request(RawPair.Finch) do
        {:ok, %{status: 204}} ->
          json(conn, %{status: "reloaded"})

        _ ->
          conn
          |> put_status(502)
          |> json(%{error: "Collaboration service could not reload this file"})
      end
    else
      {:error, error} -> conn |> put_status(422) |> json(%{error: inspect(error)})
    end
  end

  def authorize(conn, %{"ticket" => ticket, "document" => document} = params) do
    conn = RawPairWeb.InternalAuth.check(conn, :collaboration)

    if conn.halted do
      conn
    else
      age = if params["connected"] == true, do: 14 * 86400, else: 60

      with {:ok, data} <-
             Phoenix.Token.verify(RawPairWeb.Endpoint, "collaboration", ticket, max_age: age),
           true <- data.document == document,
           user when not is_nil(user) <- Accounts.user_for_hash(data.session),
           workspace <- Workspaces.get_authorized!(user, data.workspace),
           true <- data.version == workspace.collaboration_version,
           true <- Runtime.valid_path?(data.path) do
        if params["connected"] == true do
          json(conn, %{authorized: true})
        else
          case Runtime.files(workspace, :read, %{path: data.path}) do
            {:ok, %{"contents" => contents}} ->
              json(conn, %{authorized: true, contents: contents})

            {:error, error} ->
              conn |> put_status(422) |> json(%{error: inspect(error)})
          end
        end
      else
        _ -> conn |> put_status(403) |> json(%{error: "Collaboration access denied"})
      end
    end
  end
end
