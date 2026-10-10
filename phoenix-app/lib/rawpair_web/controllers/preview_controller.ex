defmodule RawPairWeb.PreviewController do
  use RawPairWeb, :controller
  import Ecto.Query
  alias RawPair.{Accounts, Applications, Workspaces, Repo}
  alias RawPair.Accounts.PreviewCredential

  plug :gateway_auth when action in [:authorize, :claim]
  defp gateway_auth(conn, _), do: RawPairWeb.InternalAuth.check(conn, :gateway)
  defp preview_host(conn), do: conn |> get_req_header("x-preview-host") |> List.first()

  def login(conn, %{"host" => host}) do
    user = conn.assigns.current_user
    app = Applications.from_host(host)

    cond do
      is_nil(app) ->
        send_resp(conn, 404, "Unknown application")

      is_nil(user) ->
        conn |> put_session(:preview_login_host, host) |> redirect(to: "/")

      not Workspaces.permitted?(user, app.workspace) ->
        send_resp(conn, 403, "Workspace membership required")

      true ->
        token = Accounts.token()

        Repo.insert_all(PreviewCredential, [
          %{
            token_hash: Accounts.hash(token),
            user_id: user.id,
            application_id: app.id,
            session_hash: Accounts.hash(get_session(conn, :session_token)),
            kind: "grant",
            expires_at: DateTime.add(Accounts.now(), 60, :second)
          }
        ])

        conn
        |> put_resp_header("referrer-policy", "no-referrer")
        |> redirect(external: Applications.url(app) <> "_rawpair/claim?token=" <> token)
    end
  end

  def claim(conn, %{"token" => token}) do
    app = Applications.from_host(preview_host(conn))

    if app do
      token_hash = Accounts.hash(token)

      query =
        from c in PreviewCredential,
          where:
            c.token_hash == ^token_hash and c.application_id == ^app.id and c.kind == "grant" and
              c.expires_at > ^Accounts.now(),
          select: c

      case Repo.transaction(fn ->
             grant = Repo.one(query |> lock("FOR UPDATE"))

             if is_nil(grant) or is_nil(Accounts.user_for_hash(grant.session_hash)) or
                  not Workspaces.permitted?(Accounts.get_user!(grant.user_id), app.workspace),
                do: Repo.rollback(:unauthorized)

             Repo.delete!(grant)
             preview_token = Accounts.token()

             Repo.insert!(%PreviewCredential{
               token_hash: Accounts.hash(preview_token),
               user_id: grant.user_id,
               application_id: app.id,
               session_hash: grant.session_hash,
               kind: "session",
               expires_at: DateTime.add(Accounts.now(), 8 * 3600, :second)
             })

             preview_token
           end) do
        {:ok, value} ->
          conn
          |> put_resp_cookie("__Host-rawpair_preview", value,
            secure: true,
            http_only: true,
            same_site: "Lax",
            path: "/",
            max_age: 8 * 3600
          )
          |> put_resp_header("cache-control", "no-store")
          |> put_resp_header("referrer-policy", "no-referrer")
          |> redirect(to: "/")

        {:error, _} ->
          send_resp(conn, 403, "Preview grant expired; reopen from RawPair")
      end
    else
      send_resp(conn, 404, "Unknown application")
    end
  end

  def claim(conn, _), do: send_resp(conn, 403, "Preview grant required")

  def authorize(conn, _) do
    app = Applications.from_host(preview_host(conn))
    conn = fetch_cookies(conn)
    token = conn.req_cookies["__Host-rawpair_preview"]
    permitted = app && (app.public || private_member?(app, token))

    cond do
      is_nil(app) ->
        send_resp(conn, 403, "Unknown application")

      not permitted ->
        send_resp(conn, 401, "Open this preview through RawPair to authenticate")

      true ->
        conn
        |> put_resp_header(
          "x-orqos-target",
          "/host/workspaces/#{app.workspace.runtime_id}/applications/#{app.name}/proxy"
        )
        |> send_resp(204, "")
    end
  end

  defp private_member?(_, nil), do: false

  defp private_member?(app, token) do
    token_hash = Accounts.hash(token)

    credential =
      Repo.one(
        from c in PreviewCredential,
          where:
            c.token_hash == ^token_hash and c.application_id == ^app.id and c.kind == "session" and
              c.expires_at > ^Accounts.now()
      )

    not is_nil(credential) and not is_nil(Accounts.user_for_hash(credential.session_hash)) and
      Workspaces.permitted?(Accounts.get_user!(credential.user_id), app.workspace)
  end
end
