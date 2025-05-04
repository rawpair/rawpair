# SPDX-License-Identifier: MPL-2.0

defmodule RawPairWeb.WorkspaceLive.FormComponent do
  use RawPairWeb, :live_component

  alias RawPair.Workspaces

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

        <.input
          field={@form[:devices]}
          type="select"
          label="Devices"
          multiple
          options={[
            {"/dev/kvm", "/dev/kvm"},
            {"/dev/snd", "/dev/snd"},
            {"/dev/ttyUSB0", "/dev/ttyUSB0"}
          ]}
        />
        <p class="text-sm text-gray-500 mt-1">These will be mounted into the container using <code>--device=</code>.</p>

        <.input
          field={@form[:cpu_limit]}
          type="text"
          label="CPU Limit"
          placeholder={"e.g. #{@default_cpu}"}
        />
        <.input
          field={@form[:mem_limit]}
          type="text"
          label="Memory Limit"
          placeholder={"e.g. #{@default_mem}"}
        />
        <.input
          field={@form[:mem_swap]}
          type="text"
          label="Memory + Swap Limit"
          placeholder={"e.g. #{@default_swap}"}
        />
        <p class="text-sm text-gray-500 mt-1">
          If unset, defaults are <code><%= @default_cpu %></code> CPUs,
          <code><%= @default_mem %></code> memory,
          <code><%= @default_swap %></code> total (memory+swap).
        </p>


        <:actions>
          <.button phx-disable-with="Saving...">Save Workspace</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{workspace: workspace} = assigns, socket) do
    platform = :persistent_term.get(:rawpair_platform)
    stacks = RawPair.Stacks.to_docker_image_tuples(RawPair.Stacks.filtered_stack_tags(platform))

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:docker_images, stacks)
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
