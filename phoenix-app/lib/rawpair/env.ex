defmodule Rawpair.Env do
  @host System.get_env("RAWPAIR_HOST") || "localhost"
  @protocol System.get_env("RAWPAIR_PROTOCOL") || "http"
  @port System.get_env("RAWPAIR_PORT") || "4000"
  @base_path System.get_env("RAWPAIR_BASE_PATH") || "/"
  def host, do: @host
  def protocol, do: @protocol
  def port, do: @port
  def base_path, do: @base_path

  def base_url do
    "#{@protocol}://#{@host}:#{@port}#{normalize_path(@base_path)}"
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
