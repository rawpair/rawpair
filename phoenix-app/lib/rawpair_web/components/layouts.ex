# SPDX-License-Identifier: MPL-2.0

defmodule RawPairWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use RawPairWeb, :controller` and
  `use RawPairWeb, :live_view`.
  """
  use RawPairWeb, :html

  embed_templates "layouts/*"
end
