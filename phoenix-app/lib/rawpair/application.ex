# SPDX-License-Identifier: MPL-2.0

defmodule RawPair.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RawPairWeb.Telemetry,
      RawPair.Repo,
      {DNSCluster, query: Application.get_env(:rawpair, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RawPair.PubSub},
      RawPair.Chat,
      # Start the Finch HTTP client for sending emails
      {Finch, name: RawPair.Finch},
      # Start a worker by calling: RawPair.Worker.start_link(arg)
      # {RawPair.Worker, arg},
      # Start to serve requests, typically the last entry
      RawPairWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RawPair.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RawPairWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
