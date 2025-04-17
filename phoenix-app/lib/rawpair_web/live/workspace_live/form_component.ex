# SPDX-License-Identifier: MPL-2.0

defmodule RawPairWeb.WorkspaceLive.FormComponent do
  use RawPairWeb, :live_component

  alias RawPair.Workspaces

  # This really should be exposed by Phoenix based on actual availability of images
  @docker_images [
    {"Ada FSF GNAT [Debian Bookworm (x64)]", "rawpair/ada:bookworm"},
    {"Ada FSF GNAT [Debian Trixie (x64)]", "rawpair/ada:trixie"},
    {"Ada FSF GNAT [Debian Trixie (arm64)]", "rawpair/ada:trixie-arm64"},
    # {"Clojure [Debian Bookworm, Temurin 21 (x64)]", "rawpair/clojure:temurin-21-bookworm"},
    {"Clojure [Debian Bookworm, Temurin 22 (x64)]", "rawpair/clojure:temurin-22-bookworm"},
    # {"Clojure [Debian Bookworm, Temurin 23 (x64)]", "rawpair/clojure:temurin-23-bookworm"},
    # {"Clojure [Debian Bookworm, Temurin 24 (x64)]", "rawpair/clojure:temurin-24-bookworm"},
    {"Elixir [Debian Bookworm (x64)]", "rawpair/elixir:bookworm"},
    {"Elixir [Debian Bookworm (arm64)]", "rawpair/elixir:bookworm-arm64"},
    {"GNU Cobol [Debian Bookworm (x64)]", "rawpair/gnucobol:bookworm"},
    {"GNU Cobol [Debian Trixie (x64)]", "rawpair/gnucobol:trixie"},
    {"Haskell [Debian Trixie (x64)]", "rawpair/haskell:trixie"},
    {"Haskell [Debian Trixie (arm64)]", "rawpair/haskell:trixie-arm64"},
    {"Julia [Debian Trixie (x64)]", "rawpair/julia:trixie"},
    {"Julia [Debian Trixie (arm64)]", "rawpair/julia:trixie-arm64"},
    {"Liberty Eiffel [Debian Bookworm (x64)]", "rawpair/liberty-eiffel:bookworm"},
    {".NET SDK 9 [Debian Bookworm (x64)]", "rawpair/dotnet:sdk9-bookworm"},
    {".NET SDK 9 [Debian Bookworm (arm64)]", "rawpair/dotnet:sdk9-bookworm-arm64"},
    {"Node.js (NVM) [Debian Trixie (x64)]", "rawpair/node:trixie"},
    {"OCaml 4.14.1 [Ubuntu 24.04 (x64)]", "rawpair/ocaml:ubuntu-2404"},
    {"OCaml 4.14.1 [Ubuntu 24.04 (arm64)]", "rawpair/ocaml:ubuntu-2404-arm64"},
    {"PHP-FPM 8.0/8.1/8.2/8.3 + Nginx [Debian Trixie (x64)]", "rawpair/php:trixie"},
    {"Python 3.12 [Debian Trixie (x64)]", "rawpair/python:trixie"},
    {"Python 3.12 [Debian Trixie (arm64)]", "rawpair/python:trixie-arm64"},
    {"Python 3.12 with AI/ML tools [CUDA 12.8.1 - Ubuntu 24.04 (x64)]", "rawpair/python-nvidia-cuda:nvidia-ubuntu24.04"},
    {"Ruby [Debian Trixie (x64)]", "rawpair/ruby:trixie"},
    {"Ruby [Debian Trixie (arm64)]", "rawpair/ruby:trixie-arm64"},
    {"Rust [Debian Trixie (x64)]", "rawpair/rust:trixie"},
    {"Rust [Debian Trixie (arm64)]", "rawpair/rust:trixie-arm64"},
    {"Steel Bank Common Lisp (2.5.2) [Debian Trixie (x64)]", "rawpair/sbcl:trixie"},
    {"Steel Bank Common Lisp (2.5.2) [Debian Trixie (arm64)]", "rawpair/sbcl:trixie-arm64"}
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
