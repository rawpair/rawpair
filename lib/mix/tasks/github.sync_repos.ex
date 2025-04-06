defmodule Mix.Tasks.Github.SyncRepos do
  use Mix.Task
  alias BeyondTabsSocial.Repo
  alias BeyondTabsSocial.Repos.Repo, as: RepoRecord

  @shortdoc "Syncs popular GitHub repos for a given language"

  @github_api "https://api.github.com/search/repositories"

  @doc """
  mix github.sync_repos Elixir
  """
  def run([language]) do
    Mix.Task.run("app.start")

    url = "#{@github_api}?q=language:#{URI.encode(language)}&sort=stars&order=desc&per_page=10"

    headers = [
      {"User-Agent", "beyond-tabs"},
      {"Accept", "application/vnd.github+json"}
    ]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        %{ "items" => repos } = Jason.decode!(body)
        Enum.each(repos, &upsert_repo(&1, language))
        IO.puts("Synced #{length(repos)} repos for #{language}")

      {:ok, %HTTPoison.Response{status_code: status}} ->
        IO.puts("GitHub returned status #{status}")

      {:error, error} ->
        IO.inspect(error, label: "HTTP request failed")
    end
  end

  defp upsert_repo(repo, language) do
    github_id = repo["id"]

    attrs = %{
      github_id: github_id,
      name: repo["name"],
      owner: repo["owner"]["login"],
      url: repo["html_url"],
      description: repo["description"],
      stars: repo["stargazers_count"],
      primary_language: language,
      last_synced_at: DateTime.utc_now()
    }

    changeset = RepoRecord.changeset(%RepoRecord{}, attrs)

    Repo.insert!(
      changeset,
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: :github_id,
      returning: true
    )
  end
end
