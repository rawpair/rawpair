# SPDX-License-Identifier: MPL-2.0

defmodule RawPair.MintUnixHTTP1 do
  @moduledoc false
  @behaviour Finch.Connection

  @impl true
  def connect(_scheme, host, port, opts) do
    socket = opts[:transport_opts][:socket]

    Mint.HTTP1.connect(
      Mint.Core.Transport.UNIX,
      host,
      port,
      Keyword.merge(opts, transport_opts: [socket: socket])
    )
  end
end
# SPDX-License-Identifier: MPL-2.0
