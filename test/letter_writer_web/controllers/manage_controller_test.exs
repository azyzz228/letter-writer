defmodule LetterWriterWeb.ManageControllerTest do
  use LetterWriterWeb.ConnCase, async: false

  alias LetterWriter.Letters
  import LetterWriter.LettersFixtures

  test "shows status without revealing content and can revoke", %{conn: conn} do
    sealed = sealed_letter()
    path = ~p"/manage/#{sealed.letter.id}/#{sealed.management_token}"

    conn = get(conn, path)
    assert html_response(conn, 200) =~ ~s(id="manage-letter")
    refute html_response(conn, 200) =~ "Under the same moon"

    conn =
      conn
      |> recycle()
      |> post(~p"/manage/#{sealed.letter.id}/#{sealed.management_token}/revoke", %{})

    assert redirected_to(conn) == path

    {:ok, status} = Letters.get_management_status(sealed.letter.id, sealed.management_token)
    assert status.status == :revoked
  end

  test "rejects an invalid management token", %{conn: conn} do
    sealed = sealed_letter()
    conn = get(conn, ~p"/manage/#{sealed.letter.id}/not-the-token")
    assert html_response(conn, 404) =~ ~s(id="management-link-unavailable")
  end
end
