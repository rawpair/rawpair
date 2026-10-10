defmodule RawPair.Accounts.PreviewCredential do
  use Ecto.Schema
  @primary_key {:token_hash, :string, autogenerate: false}
  schema "preview_credentials" do
    belongs_to :user, RawPair.Accounts.User
    belongs_to :application, RawPair.Workspaces.Application
    field :session_hash, :string
    field :kind, :string
    field :expires_at, :utc_datetime
  end
end
