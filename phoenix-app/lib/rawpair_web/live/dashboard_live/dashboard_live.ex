defmodule RawPairWeb.DashboardLive do
  use RawPairWeb, :live_view
  def mount(_, _, socket), do: {:ok, push_navigate(socket, to: ~p"/workspaces")}
end
