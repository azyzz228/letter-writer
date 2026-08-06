defmodule LetterWriterWeb.LetterControllerTest do
  use LetterWriterWeb.ConnCase, async: false

  alias LetterWriter.Letters
  import LetterWriter.LettersFixtures

  test "shows a sealed envelope without private metadata", %{conn: conn} do
    sealed = sealed_letter()
    conn = get(conn, ~p"/letters/#{sealed.letter.id}")

    assert html_response(conn, 200) =~ ~s(id="unlock-letter-form")
    refute html_response(conn, 200) =~ "Under the same moon"
    assert get_resp_header(conn, "cache-control") == ["no-store, max-age=0"]
    assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]
  end

  test "a correct password sets a reading grant cookie", %{conn: conn} do
    sealed = sealed_letter(%{"max_opens" => "1"})

    conn =
      post(conn, ~p"/letters/#{sealed.letter.id}/unlock", %{
        "unlock" => %{"password" => "quiet-moon-paper"}
      })

    assert redirected_to(conn) == ~p"/letters/#{sealed.letter.id}"
    assert conn.resp_cookies[Letters.grant_cookie_name(sealed.letter.id)].http_only

    conn = conn |> recycle() |> get(~p"/letters/#{sealed.letter.id}")
    assert html_response(conn, 200) =~ ~s(id="opened-letter")
    assert html_response(conn, 200) =~ "Under the same moon"
  end

  test "a wrong password redirects without consuming an opening", %{conn: conn} do
    sealed = sealed_letter()

    conn =
      post(conn, ~p"/letters/#{sealed.letter.id}/unlock", %{
        "unlock" => %{"password" => "not the password"}
      })

    assert redirected_to(conn) == ~p"/letters/#{sealed.letter.id}"
    {:ok, status} = Letters.get_management_status(sealed.letter.id, sealed.management_token)
    assert status.opens_used == 0
  end
end
