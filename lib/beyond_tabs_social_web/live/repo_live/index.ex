defmodule BeyondTabsSocialWeb.Repo.Index do
  use BeyondTabsSocialWeb, :live_view

  alias BeyondTabsSocial.Repos
  alias BeyondTabsSocial.Repos.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :repo_repos, Repos.list_repo_repos())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Repo live")
    |> assign(:repo, Repos.get_repo!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Repo live")
    |> assign(:repo, %Repo{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Repo repos")
    |> assign(:repo, nil)
  end

  @impl true
  def handle_info({BeyondTabsSocialWeb.RepoLive.FormComponent, {:saved, repo}}, socket) do
    {:noreply, stream_insert(socket, :repo_repos, repo)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    repo = Repos.get_repo!(id)
    {:ok, _} = Repos.delete_repo(repo)

    {:noreply, stream_delete(socket, :repo_repos, repo)}
  end
end
