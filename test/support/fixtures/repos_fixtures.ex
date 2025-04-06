defmodule BeyondTabsSocial.ReposFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BeyondTabsSocial.Repos` context.
  """

  @doc """
  Generate a repo.
  """
  def repo_fixture(attrs \\ %{}) do
    {:ok, repo} =
      attrs
      |> Enum.into(%{
        name: "some name",
        owner: "some owner",
        primary_language: "some primary_language",
        stars: 42
      })
      |> BeyondTabsSocial.Repos.create_repo()

    repo
  end
end
