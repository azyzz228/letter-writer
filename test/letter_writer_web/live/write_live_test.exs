defmodule LetterWriterWeb.WriteLiveTest do
  use LetterWriterWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LetterWriter.LettersFixtures

  test "renders the composer and seals a valid letter", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/write")

    assert has_element?(view, "#seal-letter-form")
    assert has_element?(view, "#letter-editor")
    assert has_element?(view, "#seal-letter-button")

    render_submit(view, "seal", %{"seal_form" => valid_letter_attrs()})

    assert has_element?(view, "#sealed-success")
    assert has_element?(view, "#public-letter-url")
    assert has_element?(view, "#management-letter-url")
  end
end
