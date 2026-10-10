defmodule RawPairWeb.InternalAuth do
  import Plug.Conn

  def check(conn, kind) do
    {header, config} =
      case kind do
        :gateway -> {"x-rawpair-gateway", :gateway_token}
        :collaboration -> {"authorization", :collaboration_token}
      end

    expected = Application.get_env(:rawpair, config, "")
    expected_header = if kind == :collaboration, do: "Bearer " <> expected, else: expected
    supplied = List.first(get_req_header(conn, header)) || ""

    if byte_size(expected) >= 32 and Plug.Crypto.secure_compare(supplied, expected_header),
      do: conn,
      else: conn |> send_resp(403, "Forbidden") |> halt()
  end
end
