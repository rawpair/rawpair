defmodule BeyondTabsSocialWeb.Repo.Show do
  use BeyondTabsSocialWeb, :live_view

  alias BeyondTabsSocial.Repos

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:repo, Repos.get_repo!(id))}
  end

  defp page_title(:show), do: "Show Repo live"
  defp page_title(:edit), do: "Edit Repo live"
end
