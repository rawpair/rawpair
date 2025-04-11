# SPDX-License-Identifier: MPL-2.0

defmodule RawPairWeb.PageController do
  use RawPairWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end
end
