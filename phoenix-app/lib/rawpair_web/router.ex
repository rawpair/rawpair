defmodule RawPairWeb.Router do
  use RawPairWeb, :router

  pipeline :browser do
    plug :accepts, ["html", "json"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RawPairWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug RawPairWeb.Auth
  end

  pipeline :authenticated do
    plug :require_user
  end

  defp require_user(conn, opts), do: RawPairWeb.Auth.require_user(conn, opts)

  pipeline :internal do
    plug :accepts, ["json", "html"]
    plug :fetch_session
  end

  scope "/", RawPairWeb do
    pipe_through :browser
    get "/", PageController, :home
    post "/enter", PageController, :enter
    delete "/logout", PageController, :logout
    get "/previews/:host", PreviewController, :login
  end

  scope "/", RawPairWeb do
    pipe_through [:browser, :authenticated]

    live_session :authenticated, on_mount: [{RawPairWeb.Auth, :user}] do
      live "/dashboard", DashboardLive, :index
      live "/rooms/:slug", RoomLive.Show
      live "/workspaces", WorkspaceLive.Index, :index
      live "/workspaces/new", WorkspaceLive.Index, :new
      live "/workspaces/:id/edit", WorkspaceLive.Index, :edit
      live "/workspaces/:id", WorkspaceLive.Show, :show
      live "/workspaces/:id/show/edit", WorkspaceLive.Show, :edit
    end

    get "/api/workspaces", WorkspaceController, :index
    post "/api/workspaces", WorkspaceController, :create
    get "/api/workspaces/:id", WorkspaceController, :show
    put "/api/workspaces/:id", WorkspaceController, :update
    post "/api/workspaces/:id/actions", WorkspaceController, :transition
    delete "/api/workspaces/:id", WorkspaceController, :remove
    delete "/api/workspaces/:id/project-files", WorkspaceController, :delete_files
    post "/api/workspaces/:id/members", WorkspaceController, :add_member
    delete "/api/workspaces/:id/members/:user_id", WorkspaceController, :remove_member
    post "/api/workspaces/:id/applications", WorkspaceController, :add_application

    put "/api/workspaces/:id/applications/:application_id/visibility",
        WorkspaceController,
        :visibility

    delete "/api/workspaces/:id/applications/:application_id",
           WorkspaceController,
           :remove_application

    get "/api/workspaces/:slug/files", FileController, :index
    post "/api/workspaces/:slug/collaboration/reload", CollaborationController, :reload
    get "/api/workspaces/:slug/collaboration", CollaborationController, :ticket
    get "/api/workspaces/:slug/files/*path", FileController, :get_file_contents
    put "/api/workspaces/:slug/files/*path", FileController, :update_file
  end

  scope "/internal", RawPairWeb do
    pipe_through :internal
    get "/terminal/:id", GatewayController, :terminal
    get "/previews/authorize", PreviewController, :authorize
    get "/previews/claim", PreviewController, :claim
    post "/collaboration/authorize", CollaborationController, :authorize
  end
end
