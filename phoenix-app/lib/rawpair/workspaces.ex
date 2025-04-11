# SPDX-License-Identifier: MPL-2.0

defmodule RawPair.Workspaces do
  @moduledoc """
  The Workspaces context.
  """

  import Ecto.Query, warn: false
  alias RawPair.Repo

  alias RawPair.Workspaces.Workspace

  @doc """
  Returns the list of workspaces.
  """
  def list_workspaces do
    Repo.all(Workspace)
  end

  @doc """
  Gets a single workspace.

  Raises `Ecto.NoResultsError` if the Workspace does not exist.
  """
  def get_workspace!(id), do: Repo.get!(Workspace, id)

  @doc """
  Gets a workspace by slug.
  """
  def get_workspace_by_slug!(slug), do: Repo.get_by!(Workspace, slug: slug)

  @doc """
  Creates a workspace.
  """
  def create_workspace(attrs \\ %{}) do
    %Workspace{}
    |> Workspace.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a workspace.
  """
  def update_workspace(%Workspace{} = workspace, attrs) do
    workspace
    |> Workspace.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a workspace.
  """
  def delete_workspace(%Workspace{} = workspace) do
    Repo.delete(workspace)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking workspace changes.
  """
  def change_workspace(%Workspace{} = workspace, attrs \\ %{}) do
    Workspace.changeset(workspace, attrs)
  end
end
