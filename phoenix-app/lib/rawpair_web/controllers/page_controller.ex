# SPDX-License-Identifier: MPL-2.0

defmodule RawPairWeb.PageController do
  use RawPairWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def enter(conn, %{"username" => username}) do
    username = String.trim(username)

    cond do
      username == "" ->
        conn
        |> put_flash(:error, "Username is required.")
        |> redirect(to: ~p"/")

      String.length(username) < 3 ->
        conn
        |> put_flash(:error, "Username must be at least 3 characters.")
        |> redirect(to: ~p"/")

      String.length(username) > 20 ->
        conn
        |> put_flash(:error, "Username must be at most 20 characters.")
        |> redirect(to: ~p"/")

      username =~ ~r/[^a-zA-Z0-9_-]/ ->
        conn
        |> put_flash(:error, "Username can only contain letters, numbers, hyphens, and underscores.")
        |> redirect(to: ~p"/")

      true ->
        conn
        |> put_session(:username, username)
        |> redirect(to: ~p"/dashboard")
    end
  end

  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/")
  end
end
