# SPDX-License-Identifier: MPL-2.0

defmodule RawPair.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    platform = platform_from_env()

    :persistent_term.put(:rawpair_platform, platform)

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
      RawPairWeb.Endpoint,
      RawPair.Stacks
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

  defp platform_from_env do
    case System.get_env("RAWPAIR_DOCKER_PLATFORM") do
      "linux/amd64" = plat -> plat
      "linux/arm64" = plat -> plat
      nil ->
        IO.warn("""
        [RawPair] ⚠️  RAWPAIR_DOCKER_PLATFORM not set — falling back to local host architecture.
        This may be incorrect if you're targeting a remote Docker daemon or using emulation.
        Set RAWPAIR_DOCKER_PLATFORM=linux/amd64 or linux/arm64 to suppress this warning.
        """)
        detect_local_platform()
      other -> raise "Invalid RAWPAIR_DOCKER_PLATFORM: #{inspect(other)}"
    end
  end

  defp detect_local_platform do
    {arch, 0} = System.cmd("uname", ["-m"])

    arch
    |> String.trim()
    |> case do
      "x86_64" -> "linux/amd64"
      "aarch64" -> "linux/arm64"
      other -> raise "Unsupported local platform: #{other}"
    end
  end

end
