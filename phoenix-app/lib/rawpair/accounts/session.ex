defmodule RawPair.Accounts.Session do
  use Ecto.Schema
  @primary_key {:token_hash, :string, autogenerate: false}
  schema "user_sessions" do
    belongs_to :user, RawPair.Accounts.User
    field :expires_at, :utc_datetime
  end
end
