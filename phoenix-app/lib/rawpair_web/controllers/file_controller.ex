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

    if not String.starts_with?(safe_path, base_path) do
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Invalid path"})
    else
      with {:ok, size} <- RawPair.DockerClient.get_file_stat(container, safe_path),
           true <- size <= 2 * 1024 * 1024 or {:error, :too_large},
           {:ok, mime} <- RawPair.DockerClient.get_file_mime(container, safe_path),
           true <- mime in @allowed_mime_types or {:error, {:unsupported_media_type, mime}},
           {:ok, contents} <- RawPair.DockerClient.read_file(container, safe_path) do
        json(conn, %{contents: contents})
      else
        {:error, :too_large} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "File too large"})

        {:error, {:unsupported_media_type, mime}} ->
          conn
          |> put_status(:unsupported_media_type)
          |> json(%{error: "Only text files are supported. Detected file type: #{mime}", detected: mime})

        {:error, reason} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "Failed to read file", detail: inspect(reason)})
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
      0 ->
        # Force ownership fix
        {_, chown_status} = System.cmd("docker", ["exec", "--user", "root", container, "chown", "devuser:devuser", path])
        if chown_status == 0, do: :ok, else: {:error, "chown failed with #{chown_status}"}

      _ -> {:error, "docker cp failed with #{status}"}
    end
  end





end
