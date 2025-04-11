# SPDX-License-Identifier: MPL-2.0

defmodule RawPairWeb.DashboardLive do
  use RawPairWeb, :live_view

  alias RawPair.Monitoring

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(5000, :refresh)
    {:ok, assign(socket, containers: Monitoring.list_rawpair_containers())}
  end

  @impl true
  def handle_info(:refresh, socket) do
    {:noreply, assign(socket, containers: Monitoring.list_rawpair_containers())}
  end

end
