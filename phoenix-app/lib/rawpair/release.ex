defmodule Rawpair.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :rawpair

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def create_user do
    load_app()

    {:ok, _, _} =
      Ecto.Migrator.with_repo(RawPair.Repo, fn _repo ->
        case RawPair.Accounts.create_user(
               System.fetch_env!("RAWPAIR_USERNAME"),
               System.fetch_env!("RAWPAIR_PASSWORD")
             ) do
          {:ok, user} -> IO.puts("Created account #{user.username}")
          {:error, error} -> raise "Account creation failed: #{inspect(error)}"
        end
      end)
  end

  # Retries after a crash must not create a duplicate or change an existing password.
  def bootstrap_user do
    load_app()

    {:ok, _, _} =
      Ecto.Migrator.with_repo(RawPair.Repo, fn _repo ->
        username = System.fetch_env!("RAWPAIR_USERNAME")
        password = System.fetch_env!("RAWPAIR_PASSWORD")

        case RawPair.Accounts.by_username(username) do
          nil ->
            case RawPair.Accounts.create_user(username, password, true) do
              {:ok, _user} -> :ok
              {:error, _error} -> raise "Initial account creation failed"
            end

          _user ->
            case RawPair.Accounts.authenticate(username, password) do
              {:ok, _user} -> :ok
              _ -> raise "Existing initial account does not match saved setup credentials"
            end
        end
      end)
  end

  def adopt_legacy do
    load_app()

    {:ok, _, _} =
      Ecto.Migrator.with_repo(RawPair.Repo, fn _repo ->
        RawPair.Workspaces.adopt_legacy_workspaces(System.fetch_env!("RAWPAIR_USERNAME"))
      end)
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
