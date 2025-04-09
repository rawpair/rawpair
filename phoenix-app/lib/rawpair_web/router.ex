defmodule RawPairWeb.Router do
  use RawPairWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RawPairWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RawPairWeb do
    pipe_through :browser

    get "/", PageController, :home

    live "/rooms/:slug", RoomLive.Show

    live "/repo_repos", Repo.Index, :index
    live "/repo_repos/:id", Repo.Show

    live "/workspaces", WorkspaceLive.Index, :index
    live "/workspaces/new", WorkspaceLive.Index, :new
    live "/workspaces/:id/edit", WorkspaceLive.Index, :edit

    live "/workspaces/:id", WorkspaceLive.Show, :show
    live "/workspaces/:id/show/edit", WorkspaceLive.Show, :edit

    get "/api/workspaces/:slug/files", FileController, :index
    get "/api/workspaces/:slug/files/*path", FileController, :get_file_contents
    put "/api/workspaces/:slug/files/*path", FileController, :update_file

  end

  # Other scopes may use custom stacks.
  # scope "/api", RawPairWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:rawpair, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RawPairWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
