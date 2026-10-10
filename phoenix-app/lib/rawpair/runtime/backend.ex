defmodule RawPair.Runtime.Backend do
  @moduledoc "Workspace execution boundary. Browser access policy stays in RawPair."
  @callback configure(struct()) :: {:ok, map()} | {:error, term()}
  @callback start(struct()) :: {:ok, map()} | {:error, term()}
  @callback stop(struct()) :: {:ok, map()} | {:error, term()}
  @callback remove(struct()) :: {:ok, map()} | {:error, term()}
  @callback inspect_workspace(struct()) :: {:ok, map()} | {:error, term()}
  @callback files(struct(), atom(), map()) :: {:ok, map()} | {:error, term()}
end
