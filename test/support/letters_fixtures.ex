defmodule LetterWriter.LettersFixtures do
  alias LetterWriter.Letters

  def valid_document(text \\ "Across every mile, I am still with you.") do
    Jason.encode!(%{
      "type" => "doc",
      "content" => [
        %{
          "type" => "paragraph",
          "content" => [%{"type" => "text", "text" => text}]
        }
      ]
    })
  end

  def valid_letter_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        "to_name" => "My dearest",
        "from_name" => "Always yours",
        "title" => "Under the same moon",
        "body_json" => valid_document(),
        "password" => "quiet-moon-paper",
        "password_confirmation" => "quiet-moon-paper",
        "max_opens" => "2",
        "unlimited" => "false",
        "never_expires" => "true"
      },
      overrides
    )
  end

  def sealed_letter(overrides \\ %{}) do
    {:ok, sealed} = overrides |> valid_letter_attrs() |> Letters.seal_letter()
    sealed
  end
end
