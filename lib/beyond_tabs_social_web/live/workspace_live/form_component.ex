defmodule BeyondTabsSocialWeb.WorkspaceLive.FormComponent do
  use BeyondTabsSocialWeb, :live_component

  alias BeyondTabsSocial.Workspaces

  @docker_images [
    {"Elixir (latest)", "elixir:latest"},
    {"Node.js (20)", "node:20"},
    {"Python (3.12)", "python:3.12"},
    {"Go (1.22)", "golang:1.22"},
    {"Rust (1.76)", "rust:1.76"}
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage workspace records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="workspace-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:slug]} label="Slug" readonly />
        <p class="text-sm text-gray-500 mt-1">This will be used in the URL.</p>
        <.input field={@form[:description]} type="text" label="Description" />
        <.input
          field={@form[:docker_image]}
          type="select"
          label="Docker image"
          options={@docker_images}
        />

        <.input field={@form[:with_db]} type="select" label="Database" options={[
          {"None", :none},
          {"PostgreSQL", :postgres},
          {"MySQL", :mysql},
          {"MariaDB", :mariadb}
        ]} />
        <:actions>
          <.button phx-disable-with="Saving...">Save Workspace</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end


  @impl true
  def update(%{workspace: workspace} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:docker_images, @docker_images)
     |> assign_new(:form, fn ->
       to_form(Workspaces.change_workspace(workspace))
     end)}
  end

  @impl true
  def handle_event("validate", %{"workspace" => params}, socket) do
    params = maybe_put_slug(params)

    changeset =
      socket.assigns.workspace
      |> Workspaces.change_workspace(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  defp maybe_put_slug(%{"name" => name} = params) when name != "" do
    Map.put(params, "slug", Slug.slugify(name))
  end

  defp maybe_put_slug(params), do: params

  def handle_event("save", %{"workspace" => workspace_params}, socket) do
    save_workspace(socket, socket.assigns.action, workspace_params)
  end

  defp save_workspace(socket, :edit, workspace_params) do
    case Workspaces.update_workspace(socket.assigns.workspace, workspace_params) do
      {:ok, workspace} ->
        notify_parent({:saved, workspace})

        {:noreply,
         socket
         |> put_flash(:info, "Workspace updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_workspace(socket, :new, workspace_params) do
    case Workspaces.create_workspace(workspace_params) do
      {:ok, workspace} ->
        notify_parent({:saved, workspace})

        {:noreply,
         socket
         |> put_flash(:info, "Workspace created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
