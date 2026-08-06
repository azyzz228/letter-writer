defmodule LetterWriter.Letters.Letter do
  use Ecto.Schema
  import Ecto.Changeset

  alias LetterWriter.Encrypted.Binary, as: EncryptedBinary
  alias LetterWriter.Letters.AccessGrant

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "letters" do
    field :payload, EncryptedBinary
    field :password_hash, :string, redact: true
    field :management_token_hash, :binary, redact: true
    field :max_opens, :integer
    field :opens_used, :integer, default: 0
    field :first_opened_at, :utc_datetime_usec
    field :last_opened_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec
    field :closed_at, :utc_datetime_usec
    field :closed_reason, Ecto.Enum, values: [:exhausted, :expired, :revoked]
    field :purge_at, :utc_datetime_usec

    has_many :access_grants, AccessGrant
    timestamps(type: :utc_datetime_usec)
  end

  def create_changeset(letter, attrs) do
    letter
    |> cast(attrs, [
      :payload,
      :password_hash,
      :management_token_hash,
      :max_opens,
      :expires_at
    ])
    |> validate_required([:payload, :password_hash, :management_token_hash])
    |> validate_number(:max_opens, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
    |> unique_constraint(:management_token_hash)
  end

  def close_changeset(letter, reason, now) do
    change(letter,
      closed_at: now,
      closed_reason: reason,
      purge_at: DateTime.add(now, 30, :day)
    )
  end
end
