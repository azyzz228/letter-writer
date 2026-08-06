defmodule LetterWriter.Letters.AccessGrant do
  use Ecto.Schema
  import Ecto.Changeset

  alias LetterWriter.Letters.Letter

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "letter_access_grants" do
    field :token_hash, :binary, redact: true
    field :expires_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec

    belongs_to :letter, Letter
    timestamps(updated_at: false, type: :utc_datetime_usec)
  end

  def changeset(grant, attrs) do
    grant
    |> cast(attrs, [:token_hash, :expires_at])
    |> validate_required([:token_hash, :expires_at])
    |> unique_constraint(:token_hash)
  end
end
