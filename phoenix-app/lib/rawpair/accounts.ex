defmodule RawPair.Accounts do
  import Ecto.Query
  alias RawPair.Repo
  alias RawPair.Accounts.{User, Session}
  @iterations 600_000
  @session_days 14

  def hash(token), do: :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)
  def token, do: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  def now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  def create_user(username, password, admin \\ false) do
    if is_binary(password) and byte_size(password) >= 12 and byte_size(password) <= 1024 do
      salt = :crypto.strong_rand_bytes(16)
      digest = :crypto.pbkdf2_hmac(:sha256, password, salt, @iterations, 32)
      encoded = "pbkdf2:#{@iterations}:#{Base.encode64(salt)}:#{Base.encode64(digest)}"

      %User{}
      |> User.changeset(%{username: username, password_hash: encoded, admin: admin})
      |> Repo.insert()
    else
      {:error, :password_must_have_12_to_1024_bytes}
    end
  end

  def authenticate(username, password)
      when is_binary(username) and is_binary(password) and byte_size(password) <= 1024 do
    user = Repo.get_by(User, username: username)
    # Derive a key even for missing users to avoid a cheap username oracle.
    encoded =
      if user,
        do: user.password_hash,
        else:
          "pbkdf2:#{@iterations}:AAAAAAAAAAAAAAAAAAAAAA==:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

    ["pbkdf2", rounds, salt, expected] = String.split(encoded, ":")

    candidate =
      :crypto.pbkdf2_hmac(:sha256, password, Base.decode64!(salt), String.to_integer(rounds), 32)

    if Plug.Crypto.secure_compare(candidate, Base.decode64!(expected)) and user,
      do: {:ok, user},
      else: {:error, :invalid_credentials}
  end

  def authenticate(_, _), do: {:error, :invalid_credentials}

  def create_session(user) do
    token = token()

    Repo.insert_all(Session, [
      %{
        token_hash: hash(token),
        user_id: user.id,
        expires_at: DateTime.add(now(), @session_days * 86400, :second)
      }
    ])

    token
  end

  def user_for_session(token) when is_binary(token), do: user_for_hash(hash(token))
  def user_for_session(_), do: nil

  def user_for_hash(token_hash) when is_binary(token_hash) do
    Repo.one(
      from u in User,
        join: s in Session,
        on: s.user_id == u.id,
        where: s.token_hash == ^token_hash and s.expires_at > ^now(),
        select: u
    )
  end

  def user_for_hash(_), do: nil

  def delete_session(token) when is_binary(token) do
    token_hash = hash(token)
    Repo.delete_all(from s in Session, where: s.token_hash == ^token_hash)
    RawPairWeb.Endpoint.broadcast("session:#{token_hash}", "disconnect", %{})
    :ok
  end

  def delete_session(_), do: :ok

  def get_user!(id), do: Repo.get!(User, id)
  def by_username(username), do: Repo.get_by(User, username: username)
end
