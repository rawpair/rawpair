defmodule BeyondTabsSocialWeb.Repo.FormComponent do
  use BeyondTabsSocialWeb, :live_component

  alias BeyondTabsSocial.Repos

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage repo records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="repo-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:owner]} type="text" label="Owner" />
        <.input field={@form[:primary_language]} type="text" label="Primary language" />
        <.input field={@form[:stars]} type="number" label="Stars" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Repo live</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{repo: repo} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Repos.change_repo(repo))
     end)}
  end

  @impl true
  def handle_event("validate", %{"repo" => repo_params}, socket) do
    changeset = Repos.change_repo(socket.assigns.repo, repo_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"repo" => repo_params}, socket) do
    save_repo(socket, socket.assigns.action, repo_params)
  end

  defp save_repo(socket, :edit, repo_params) do
    case Repos.update_repo(socket.assigns.repo, repo_params) do
      {:ok, repo} ->
        notify_parent({:saved, repo})

        {:noreply,
         socket
         |> put_flash(:info, "Repo live updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_repo(socket, :new, repo_params) do
    case Repos.create_repo(repo_params) do
      {:ok, repo} ->
        notify_parent({:saved, repo})

        {:noreply,
         socket
         |> put_flash(:info, "Repo live created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
