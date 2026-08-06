defmodule LetterWriterWeb.LetterController do
  use LetterWriterWeb, :controller

  alias LetterWriter.Letters

  def show(conn, %{"id" => id}) do
    conn = fetch_cookies(conn)
    grant_token = conn.cookies[Letters.grant_cookie_name(id)]

    case Letters.get_letter_for_grant(id, grant_token) do
      {:ok, payload} ->
        render(conn, :read, payload: payload, page_title: payload["title"] || "A private letter")

      {:error, :invalid_grant} ->
        case Letters.public_status(id) do
          :sealed ->
            render(conn, :locked,
              letter_id: id,
              form: Phoenix.Component.to_form(%{"password" => ""}, as: :unlock),
              page_title: "A sealed letter"
            )

          :not_found ->
            conn
            |> put_status(:not_found)
            |> render(:unavailable, page_title: "Letter unavailable")

          :unavailable ->
            render(conn, :unavailable, page_title: "Letter unavailable")
        end
    end
  end

  def unlock(conn, %{"id" => id, "unlock" => %{"password" => password}}) do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()

    with :ok <- Letters.check_unlock_rate(ip, id),
         {:ok, grant} <- Letters.unlock_letter(id, password) do
      conn
      |> put_resp_cookie(Letters.grant_cookie_name(id), grant.token,
        max_age: Letters.grant_lifetime(),
        path: ~p"/letters/#{id}",
        http_only: true,
        secure: conn.scheme == :https,
        same_site: "Lax"
      )
      |> redirect(to: ~p"/letters/#{id}")
    else
      {:error, :unlock_failed} ->
        :telemetry.execute([:letter_writer, :letters, :unlock_failed], %{count: 1})

        conn
        |> put_flash(
          :error,
          "That password did not open this letter, or the letter is no longer available."
        )
        |> redirect(to: ~p"/letters/#{id}")

      {:error, _retry_after} ->
        conn
        |> put_flash(:error, "Too many attempts. Please wait before trying again.")
        |> redirect(to: ~p"/letters/#{id}")
    end
  end

  def unlock(conn, %{"id" => id}) do
    conn
    |> put_flash(:error, "Enter the letter password to continue.")
    |> redirect(to: ~p"/letters/#{id}")
  end
end
