defmodule LetterWriter.ConcurrentUnlockTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias LetterWriter.Letters
  alias LetterWriter.Letters.{AccessGrant, Letter}
  alias LetterWriter.Repo
  import LetterWriter.LettersFixtures

  setup do
    Sandbox.mode(Repo, :auto)
    Repo.delete_all(AccessGrant)
    Repo.delete_all(Letter)

    on_exit(fn -> Sandbox.mode(Repo, :manual) end)
    :ok
  end

  test "twenty concurrent correct unlocks issue exactly one grant for a one-open letter" do
    sealed = sealed_letter(%{"max_opens" => "1"})

    results =
      1..20
      |> Task.async_stream(
        fn _ -> Letters.unlock_letter(sealed.letter.id, "quiet-moon-paper") end,
        max_concurrency: 20,
        ordered: false,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Repo.aggregate(AccessGrant, :count) == 1
    assert Repo.get!(Letter, sealed.letter.id).opens_used == 1
  end
end
