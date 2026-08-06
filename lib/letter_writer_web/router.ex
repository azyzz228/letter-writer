defmodule LetterWriterWeb.Router do
  use LetterWriterWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LetterWriterWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug LetterWriterWeb.Plugs.PrivateHeaders
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LetterWriterWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/write", WriteLive
    get "/letters/:id", LetterController, :show
    post "/letters/:id/unlock", LetterController, :unlock
    get "/manage/:id/:token", ManageController, :show
    post "/manage/:id/:token/revoke", ManageController, :revoke
  end

  # Other scopes may use custom stacks.
  # scope "/api", LetterWriterWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:letter_writer, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LetterWriterWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
