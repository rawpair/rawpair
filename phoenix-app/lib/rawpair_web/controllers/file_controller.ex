defmodule RawPairWeb.FileController do
  use RawPairWeb, :controller
  alias RawPair.{Workspaces, Runtime}

  def index(conn, %{"slug" => slug}) do
    workspace = Workspaces.by_slug_authorized!(conn.assigns.current_user, slug)
    respond(conn, Runtime.files(workspace, :list))
  end

  def get_file_contents(conn, %{"slug" => slug, "path" => parts}) do
    workspace = Workspaces.by_slug_authorized!(conn.assigns.current_user, slug)
    respond(conn, Runtime.files(workspace, :read, %{path: Enum.join(parts, "/")}))
  end

  def update_file(conn, %{"slug" => slug, "path" => parts, "content" => content})
      when is_binary(content) do
    workspace = Workspaces.by_slug_authorized!(conn.assigns.current_user, slug)

    respond(
      conn,
      Runtime.files(workspace, :write, %{path: Enum.join(parts, "/"), content: content})
    )
  end

  defp respond(conn, {:ok, data}), do: json(conn, data)

  defp respond(conn, {:error, error}),
    do: conn |> put_status(422) |> json(%{error: inspect(error)})
end
