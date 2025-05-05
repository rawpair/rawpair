defmodule RawPair.Stacks do
  use GenServer

  @default_stack_version "0.1.5"
  @cache_key :stacks_json
  @cache_ttl_ms 30 * 60 * 1000  # 30 minutes

  def stack_version do
    System.get_env("RAWPAIR_STACKS_VERSION") || @default_stack_version
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_state) do
    :ets.new(:rawpair_stacks_cache, [:named_table, :public, read_concurrency: true])
    {:ok, %{}}
  end

  def fetch_stacks do
    now = System.system_time(:millisecond)

    case :ets.lookup(:rawpair_stacks_cache, @cache_key) do
      [{_, %{expires_at: expires, value: stacks}}] when expires > now ->
        stacks

      _ ->
        stacks = download_stacks_json()
        :ets.insert(:rawpair_stacks_cache, {@cache_key, %{expires_at: now + @cache_ttl_ms, value: stacks}})
        stacks
    end
  end

  def filtered_stack_tags(platform) do
    fetch_stacks()
    |> Enum.flat_map(& &1["tags"])
    |> Enum.filter(fn tag ->
      platform in tag["platforms"]
    end)
  end

  def to_docker_image_tuples(tags) do
    Enum.map(tags, fn tag ->
      label = "#{tag["name"]}"
      image = "rawpair/#{tag["id"]}"

      {label, image}
    end)
  end

  defp download_stacks_json do
    version = stack_version()
    url = "https://raw.githubusercontent.com/rawpair/stacks/v#{version}/stacks/stacks.json"

    case Finch.build(:get, url) |> Finch.request(RawPair.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        Jason.decode!(body)

      {:ok, %Finch.Response{status: status}} ->
        raise "Failed to fetch stacks.json: HTTP #{status}"

      {:error, reason} ->
        raise "Failed to fetch stacks.json: #{inspect(reason)}"
    end
  end

end
