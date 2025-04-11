# SPDX-License-Identifier: MPL-2.0

defmodule Rawpair.Env do
  def host, do: System.get_env("RAWPAIR_HOST") || "localhost"
  def protocol, do: System.get_env("RAWPAIR_PROTOCOL") || "http"
  def port, do: System.get_env("RAWPAIR_PORT") || "4000"
  def base_path, do: System.get_env("RAWPAIR_BASE_PATH") || "/"

  def terminal_host, do: System.get_env("RAWPAIR_TERMINAL_HOST") || "localhost"
  def terminal_port, do: System.get_env("RAWPAIR_TERMINAL_PORT") || "8080"

  def grafana_host, do: System.get_env("RAWPAIR_GRAFANA_HOST") || "localhost"
  def grafana_port, do: System.get_env("RAWPAIR_GRAFANA_PORT") || "3000"

  def base_url do
    "#{protocol()}://#{host()}:#{port()}#{normalize_path(base_path())}"
  end

  def terminal_base_url do
    "#{protocol()}://#{terminal_host()}:#{terminal_port()}/"
  end

  def grafana_base_url do
    "#{protocol()}://#{grafana_host()}:#{grafana_port()}/"
  end

  defp normalize_path(path) do
    path = String.trim(path)

    cond do
      path in ["", "/"] -> ""
      String.starts_with?(path, "/") -> path
      true -> "/#{path}"
    end
  end
end
