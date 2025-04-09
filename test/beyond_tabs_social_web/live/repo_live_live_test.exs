defmodule RawPairWeb.RepoLiveTest do
  use RawPairWeb.ConnCase

  import Phoenix.LiveViewTest
  import RawPair.ReposFixtures

  @create_attrs %{name: "some name", owner: "some owner", primary_language: "some primary_language", stars: 42}
  @update_attrs %{name: "some updated name", owner: "some updated owner", primary_language: "some updated primary_language", stars: 43}
  @invalid_attrs %{name: nil, owner: nil, primary_language: nil, stars: nil}

  defp create_repo(_) do
    repo = repo_fixture()
    %{repo: repo}
  end

  describe "Index" do
    setup [:create_repo]

    test "lists all repo_repos", %{conn: conn, repo: repo} do
      {:ok, _index_live, html} = live(conn, ~p"/repo_repos")

      assert html =~ "Listing Repo repos"
      assert html =~ repo.name
    end

    test "saves new repo", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/repo_repos")

      assert index_live |> element("a", "New Repo live") |> render_click() =~
               "New Repo live"

      assert_patch(index_live, ~p"/repo_repos/new")

      assert index_live
             |> form("#repo-form", repo: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#repo-form", repo: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/repo_repos")

      html = render(index_live)
      assert html =~ "Repo live created successfully"
      assert html =~ "some name"
    end

    test "updates repo in listing", %{conn: conn, repo: repo} do
      {:ok, index_live, _html} = live(conn, ~p"/repo_repos")

      assert index_live |> element("#repo_repos-#{repo.id} a", "Edit") |> render_click() =~
               "Edit Repo live"

      assert_patch(index_live, ~p"/repo_repos/#{repo}/edit")

      assert index_live
             |> form("#repo-form", repo: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#repo-form", repo: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/repo_repos")

      html = render(index_live)
      assert html =~ "Repo live updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes repo in listing", %{conn: conn, repo: repo} do
      {:ok, index_live, _html} = live(conn, ~p"/repo_repos")

      assert index_live |> element("#repo_repos-#{repo.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#repo_repos-#{repo.id}")
    end
  end

  describe "Show" do
    setup [:create_repo]

    test "displays repo", %{conn: conn, repo: repo} do
      {:ok, _show_live, html} = live(conn, ~p"/repo_repos/#{repo}")

      assert html =~ "Show Repo live"
      assert html =~ repo.name
    end

    test "updates repo within modal", %{conn: conn, repo: repo} do
      {:ok, show_live, _html} = live(conn, ~p"/repo_repos/#{repo}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Repo live"

      assert_patch(show_live, ~p"/repo_repos/#{repo}/show/edit")

      assert show_live
             |> form("#repo-form", repo: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#repo-form", repo: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/repo_repos/#{repo}")

      html = render(show_live)
      assert html =~ "Repo live updated successfully"
      assert html =~ "some updated name"
    end
  end
end
