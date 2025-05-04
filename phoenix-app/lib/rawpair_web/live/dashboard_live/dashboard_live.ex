# SPDX-License-Identifier: MPL-2.0

defmodule RawPairWeb.DashboardLive do
  use RawPairWeb, :live_view

  require Logger

  alias RawPair.Monitoring

  @impl true
  def mount(_params, session, socket) do
    username = session["username"]

    if connected?(socket), do: :timer.send_interval(5000, :refresh)
    {:ok, assign(socket, containers: Monitoring.list_rawpair_containers(), username: username)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, assign(socket, containers: Monitoring.list_rawpair_containers())}
  end

  @impl true
  def handle_event("stop", %{"id" => id}, socket) do
    case RawPair.DockerClient.stop(id) do
      :ok ->
        containers = Monitoring.list_rawpair_containers()
        {:noreply, assign(socket, containers: containers)}

      {:error, {:stop_failed, reason}} ->
        # Log or handle error, maybe flash a message
        Logger.warning("Failed to stop container #{id}: #{inspect(reason)}")
        {:noreply, put_flash(socket, :error, "Failed to stop container.")}
    end
  end
end
