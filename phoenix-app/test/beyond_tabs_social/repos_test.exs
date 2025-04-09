defmodule RawPair.ReposTest do
  use RawPair.DataCase

  alias RawPair.Repos

  describe "repo_repos" do
    alias RawPair.Repos.Repo

    import RawPair.ReposFixtures

    @invalid_attrs %{name: nil, owner: nil, primary_language: nil, stars: nil}

    test "list_repo_repos/0 returns all repo_repos" do
      repo = repo_fixture()
      assert Repos.list_repo_repos() == [repo]
    end

    test "get_repo!/1 returns the repo with given id" do
      repo = repo_fixture()
      assert Repos.get_repo!(repo.id) == repo
    end

    test "create_repo/1 with valid data creates a repo" do
      valid_attrs = %{name: "some name", owner: "some owner", primary_language: "some primary_language", stars: 42}

      assert {:ok, %Repo{} = repo} = Repos.create_repo(valid_attrs)
      assert repo.name == "some name"
      assert repo.owner == "some owner"
      assert repo.primary_language == "some primary_language"
      assert repo.stars == 42
    end

    test "create_repo/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Repos.create_repo(@invalid_attrs)
    end

    test "update_repo/2 with valid data updates the repo" do
      repo = repo_fixture()
      update_attrs = %{name: "some updated name", owner: "some updated owner", primary_language: "some updated primary_language", stars: 43}

      assert {:ok, %Repo{} = repo} = Repos.update_repo(repo, update_attrs)
      assert repo.name == "some updated name"
      assert repo.owner == "some updated owner"
      assert repo.primary_language == "some updated primary_language"
      assert repo.stars == 43
    end

    test "update_repo/2 with invalid data returns error changeset" do
      repo = repo_fixture()
      assert {:error, %Ecto.Changeset{}} = Repos.update_repo(repo, @invalid_attrs)
      assert repo == Repos.get_repo!(repo.id)
    end

    test "delete_repo/1 deletes the repo" do
      repo = repo_fixture()
      assert {:ok, %Repo{}} = Repos.delete_repo(repo)
      assert_raise Ecto.NoResultsError, fn -> Repos.get_repo!(repo.id) end
    end

    test "change_repo/1 returns a repo changeset" do
      repo = repo_fixture()
      assert %Ecto.Changeset{} = Repos.change_repo(repo)
    end
  end
end
