defmodule RawPair.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :username, :string
    field :password_hash, :string, redact: true
    field :admin, :boolean, default: false
    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :password_hash, :admin])
    |> validate_required([:username, :password_hash])
    |> validate_format(:username, ~r/^[a-zA-Z0-9_-]{3,40}$/)
    |> unique_constraint(:username)
  end
end
