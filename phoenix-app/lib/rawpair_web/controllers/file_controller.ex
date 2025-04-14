# SPDX-License-Identifier: MPL-2.0

defmodule RawPairWeb.FileController do
  use RawPairWeb, :controller

  alias RawPair.Workspaces
  alias RawPair.Docker.WorkspaceManager

  @allowed_mime_types [
    "text/plain",
    "text/x-c",
    "text/x-c++",
    "text/css",
    "text/x-common-lisp",
    "text/x-elixir",
    "text/x-erlang",
    "text/x-go",
    "text/x-haskell",
    "text/html",
    "text/x-java-source",
    "text/x-lua",
    "text/x-ocaml",
    "text/x-pascal",
    "text/x-php",
    "text/x-python",
    "text/x-script.python",
    "text/x-ruby",
    "text/x-rustsrc",
    "text/x-scala",
    "text/x-scheme",
    "text/x-shellscript",
    "application/json",
    "application/javascript",
    "application/xml",
    "application/x-typescript"
  ]

  def index(conn, %{"slug" => slug}) do
    case WorkspaceManager.list_files(slug) do
      {:ok, files} ->
        json(conn, %{files: files})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: reason})
    end
  end

  def get_file_contents(conn, %{"slug" => slug, "path" => file_path_parts}) do
    workspace = Workspaces.get_workspace_by_slug!(slug)
    container = "workspace-#{workspace.slug}"
    base_path = "/home/devuser/app"

    full_path = Path.join([base_path | file_path_parts])
    safe_path = Path.expand(full_path)

    if String.slice(safe_path, 0, String.length(base_path)) != base_path do
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Invalid path"})
    else
      # First: check file size
      size_cmd = ["exec", container, "stat", "-c", "%s", safe_path]
      case System.cmd("docker", size_cmd, stderr_to_stdout: true) do
        {size_str, 0} ->
          size = String.trim(size_str) |> String.to_integer()

          if size > 2 * 1024 * 1024 do
            conn
            |> put_status(:bad_request)
            |> json(%{error: "File too large"})
          else
            # Second: check MIME type
            mime_cmd = ["exec", container, "file", "--brief", "--mime-type", safe_path]

            case System.cmd("docker", mime_cmd, stderr_to_stdout: true) do
              {mime, 0} ->
                mime = String.trim(mime)

                if mime in @allowed_mime_types do
                  cat_cmd = ["exec", container, "cat", safe_path]

                  case System.cmd("docker", cat_cmd, stderr_to_stdout: true) do
                    {contents, 0} ->
                      json(conn, %{contents: contents})

                    {err, _} ->
                      conn
                      |> put_status(:internal_server_error)
                      |> json(%{error: "Failed to read file", detail: err})
                  end
                else
                  conn
                  |> put_status(:unsupported_media_type)
                  |> json(%{error: "Only text files are supported. Detected file type: #{mime}", detected: mime})
                end

              _ ->
                conn
                |> put_status(:unsupported_media_type)
                |> json(%{error: "Unable to detect mime type of file"})
            end
          end

        {err, _} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "File not found", detail: err})
      end
    end
  end


  def update_file(conn, %{"slug" => slug, "path" => file_path_parts, "content" => content}) do
    workspace = Workspaces.get_workspace_by_slug!(slug)
    container = "workspace-#{workspace.slug}"
    base_path = "/home/devuser/app"
    full_path = Path.expand(Path.join([base_path | file_path_parts]))

    if not String.starts_with?(full_path, base_path) do
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Invalid path"})
    else
      case write_file(container, full_path, content) do
        :ok ->
          json(conn, %{status: "ok"})

        {:error, reason} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "Failed to write file", detail: reason})
      end
    end
  end

  def write_file(container, path, content) do
    tmp = Path.join(System.tmp_dir!(), "bt-docker-write-#{:erlang.unique_integer([:positive])}")
    File.write!(tmp, content)

    {_, status} = System.cmd("docker", ["cp", tmp, "#{container}:#{path}"])
    File.rm(tmp)

    case status do
      0 -> :ok
      _ -> {:error, "docker cp failed with #{status}"}
    end
  end





end
