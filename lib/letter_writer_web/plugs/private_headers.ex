defmodule LetterWriterWeb.Plugs.PrivateHeaders do
  @moduledoc false
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("cache-control", "no-store, max-age=0")
    |> put_resp_header("pragma", "no-cache")
    |> put_resp_header("referrer-policy", "no-referrer")
    |> put_resp_header("x-robots-tag", "noindex, nofollow, noarchive")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'self'; img-src 'self' data:; font-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self'; connect-src 'self' ws: wss:; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'"
    )
    |> put_resp_header("permissions-policy", "camera=(), microphone=(), geolocation=()")
  end
end
