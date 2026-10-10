defmodule RawPairWeb.GatewayController do
  use RawPairWeb, :controller
  plug :gateway_auth
  alias RawPair.{Workspaces, Runtime}

  defp gateway_auth(conn, _), do: RawPairWeb.InternalAuth.check(conn, :gateway)

  def terminal(conn, %{"id" => id}) do
    workspace =
      if String.starts_with?(id, "docker-") do
        case Integer.parse(String.replace_prefix(id, "docker-", "")) do
          {number, ""} -> RawPair.Repo.get(Workspaces.Workspace, number)
          _ -> nil
        end
      else
        Workspaces.get_by_runtime(id)
      end

    user = RawPair.Accounts.user_for_session(get_session(conn, :session_token))

    if workspace && Workspaces.permitted?(user, workspace) do
      case Runtime.inspect_workspace(workspace) do
        {:ok, %{"status" => "running"}} ->
          if workspace.backend == :host do
            conn
            |> put_resp_header(
              "x-orqos-target",
              "/host/workspaces/#{workspace.runtime_id}/terminal"
            )
            |> send_resp(204, "")
          else
            # Only a registered container's allocated ttyd port is returned.
            conn
            |> put_resp_header("x-docker-terminal-container", "workspace-#{workspace.slug}")
            |> put_resp_header("x-docker-terminal-port", to_string(workspace.workspace_port))
            |> send_resp(204, "")
          end

        _ ->
          send_resp(conn, 503, "Workspace is stopped or unavailable")
      end
    else
      send_resp(conn, 403, "Workspace membership required")
    end
  end
end
