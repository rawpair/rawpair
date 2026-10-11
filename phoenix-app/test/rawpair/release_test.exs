defmodule Rawpair.ReleaseTest do
  use RawPair.DataCase, async: false

  setup do
    previous = Map.new(~w(RAWPAIR_USERNAME RAWPAIR_PASSWORD), &{&1, System.get_env(&1)})

    on_exit(fn ->
      for {key, value} <- previous do
        if value, do: System.put_env(key, value), else: System.delete_env(key)
      end
    end)

    System.put_env("RAWPAIR_USERNAME", "bootstrap_test")
    System.put_env("RAWPAIR_PASSWORD", "protected-initial-password")
    :ok
  end

  test "bootstrap retries preserve the existing identity and password" do
    Rawpair.Release.bootstrap_user()
    first = RawPair.Accounts.by_username("bootstrap_test")
    assert first.admin
    Rawpair.Release.bootstrap_user()
    assert RawPair.Accounts.by_username("bootstrap_test").id == first.id

    assert {:ok, _} =
             RawPair.Accounts.authenticate("bootstrap_test", "protected-initial-password")

    System.put_env("RAWPAIR_PASSWORD", "different-password-value")

    assert_raise RuntimeError, ~r/does not match saved setup credentials/, fn ->
      Rawpair.Release.bootstrap_user()
    end

    assert {:ok, _} =
             RawPair.Accounts.authenticate("bootstrap_test", "protected-initial-password")
  end
end
