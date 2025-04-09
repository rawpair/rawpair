defmodule RawPair.Repos do
  @moduledoc """
  The Repos context.
  """

  import Ecto.Query, warn: false
  alias RawPair.Repo, as: DB
  alias RawPair.Repos.Repo

  @doc """
  Returns the list of repo_repos.
  """
  def list_repo_repos do
    DB.all(Repo)
  end

  @doc """
  Gets a single repo.

  Raises `Ecto.NoResultsError` if the Repo does not exist.
  """
  def get_repo!(id), do: DB.get!(Repo, id)

  @doc """
  Creates a repo.
  """
  def create_repo(attrs \\ %{}) do
    %Repo{}
    |> Repo.changeset(attrs)
    |> DB.insert()
  end

  @doc """
  Updates a repo.
  """
  def update_repo(%Repo{} = repo, attrs) do
    repo
    |> Repo.changeset(attrs)
    |> DB.update()
  end

  @doc """
  Deletes a repo.
  """
  def delete_repo(%Repo{} = repo) do
    DB.delete(repo)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking repo changes.
  """
  def change_repo(%Repo{} = repo, attrs \\ %{}) do
    Repo.changeset(repo, attrs)
  end
end
