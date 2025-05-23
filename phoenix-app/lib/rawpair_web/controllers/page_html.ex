# SPDX-License-Identifier: MPL-2.0

defmodule RawPairWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use RawPairWeb, :html

  embed_templates "page_html/*"
end
