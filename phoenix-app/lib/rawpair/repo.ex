# SPDX-License-Identifier: MPL-2.0

defmodule RawPair.Repo do
  use Ecto.Repo,
    otp_app: :rawpair,
    adapter: Ecto.Adapters.Postgres
end
