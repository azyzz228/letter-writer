defmodule LetterWriter.LettersTest do
  use LetterWriter.DataCase, async: false

  alias LetterWriter.Letters
  alias LetterWriter.Letters.{Content, Letter}
  alias LetterWriter.Repo
  import LetterWriter.LettersFixtures

  describe "seal_letter/1" do
    test "stores a decryptable payload as ciphertext in PostgreSQL" do
      sealed = sealed_letter()

      raw_payload =
        Ecto.Adapters.SQL.query!(Repo, "SELECT payload FROM letters WHERE id = $1", [
          Ecto.UUID.dump!(sealed.letter.id)
        ]).rows
        |> hd()
        |> hd()

      refute raw_payload =~ "Under the same moon"

      stored = Repo.get!(Letter, sealed.letter.id)
      assert stored.payload =~ "Under the same moon"
      assert stored.password_hash =~ "$argon2id$"
      refute stored.management_token_hash == sealed.management_token
    end

    test "rejects short passwords and unsupported content" do
      attrs =
        valid_letter_attrs(%{
          "password" => "short",
          "password_confirmation" => "short",
          "body_json" => Jason.encode!(%{"type" => "image", "src" => "bad"})
        })

      assert {:error, changeset} = Letters.seal_letter(attrs)
      assert "should be at least 8 character(s)" in errors_on(changeset).password
    end
  end

  describe "content safety" do
    test "escapes text, drops unsafe links, and preserves allowlisted formatting" do
      json =
        Jason.encode!(%{
          "type" => "doc",
          "content" => [
            %{
              "type" => "paragraph",
              "attrs" => %{"textAlign" => "center"},
              "content" => [
                %{
                  "type" => "text",
                  "text" => "<script>alert(1)</script>",
                  "marks" => [
                    %{"type" => "bold"},
                    %{"type" => "link", "attrs" => %{"href" => "javascript:alert(1)"}}
                  ]
                }
              ]
            }
          ]
        })

      assert {:ok, payload} = Content.prepare(json)
      assert payload["html"] =~ ~s(class="align-center")
      assert payload["html"] =~ "<strong>&lt;script&gt;"
      refute payload["html"] =~ "javascript:"
      refute payload["html"] =~ "<script>"
    end
  end

  describe "unlocking and grants" do
    test "a wrong password never consumes an opening" do
      sealed = sealed_letter()

      assert {:error, :unlock_failed} = Letters.unlock_letter(sealed.letter.id, "wrong password")

      assert {:ok, status} =
               Letters.get_management_status(sealed.letter.id, sealed.management_token)

      assert status.opens_used == 0
      assert status.status == :sealed
    end

    test "the final unlock closes the letter while its grant remains readable" do
      sealed = sealed_letter(%{"max_opens" => "1"})

      assert {:ok, grant} = Letters.unlock_letter(sealed.letter.id, "quiet-moon-paper")

      assert {:error, :unlock_failed} =
               Letters.unlock_letter(sealed.letter.id, "quiet-moon-paper")

      assert {:ok, payload} = Letters.get_letter_for_grant(sealed.letter.id, grant.token)
      assert payload["title"] == "Under the same moon"

      assert {:ok, status} =
               Letters.get_management_status(sealed.letter.id, sealed.management_token)

      assert status.status == :exhausted
      assert status.opens_used == 1
      assert status.purge_at
    end

    test "revocation immediately invalidates existing grants" do
      sealed = sealed_letter()
      {:ok, grant} = Letters.unlock_letter(sealed.letter.id, "quiet-moon-paper")

      assert {:ok, _status} = Letters.revoke_letter(sealed.letter.id, sealed.management_token)

      assert {:error, :invalid_grant} =
               Letters.get_letter_for_grant(sealed.letter.id, grant.token)

      assert {:ok, status} =
               Letters.get_management_status(sealed.letter.id, sealed.management_token)

      assert status.status == :revoked
    end

    test "expired letters reject new unlocks" do
      sealed = sealed_letter()
      past = DateTime.add(DateTime.utc_now(), -60, :second)

      Letter
      |> Repo.get!(sealed.letter.id)
      |> Ecto.Changeset.change(expires_at: past)
      |> Repo.update!()

      assert {:error, :unlock_failed} =
               Letters.unlock_letter(sealed.letter.id, "quiet-moon-paper")

      assert :ok = Letters.expire_letter(sealed.letter.id)
      assert Repo.get!(Letter, sealed.letter.id).closed_reason == :expired
    end

    test "purge permanently deletes a due closed letter" do
      sealed = sealed_letter()
      now = DateTime.utc_now()

      Letter
      |> Repo.get!(sealed.letter.id)
      |> Ecto.Changeset.change(
        closed_at: now,
        closed_reason: :revoked,
        purge_at: DateTime.add(now, -1, :second)
      )
      |> Repo.update!()

      assert :ok = Letters.purge_letter(sealed.letter.id)
      refute Repo.get(Letter, sealed.letter.id)
    end
  end
end
