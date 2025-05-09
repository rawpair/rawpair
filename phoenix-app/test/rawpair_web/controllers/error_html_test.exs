# SPDX-License-Identifier: MPL-2.0

defmodule RawPairWeb.ErrorHTMLTest do
  use RawPairWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template

  test "renders 404.html" do
    assert render_to_string(RawPairWeb.ErrorHTML, "404", "html", []) == "Not Found"
  end

  test "renders 500.html" do
    assert render_to_string(RawPairWeb.ErrorHTML, "500", "html", []) == "Internal Server Error"
  end
end
