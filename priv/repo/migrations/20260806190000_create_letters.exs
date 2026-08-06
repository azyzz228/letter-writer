defmodule LetterWriter.Repo.Migrations.CreateLetters do
  use Ecto.Migration

  def change do
    create table(:letters, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :payload, :binary, null: false
      add :password_hash, :text, null: false
      add :management_token_hash, :binary, null: false
      add :max_opens, :integer
      add :opens_used, :integer, null: false, default: 0
      add :first_opened_at, :utc_datetime_usec
      add :last_opened_at, :utc_datetime_usec
      add :expires_at, :utc_datetime_usec
      add :closed_at, :utc_datetime_usec
      add :closed_reason, :string
      add :purge_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:letters, [:management_token_hash])
    create index(:letters, [:expires_at])
    create index(:letters, [:purge_at])

    create constraint(:letters, :valid_max_opens,
             check: "max_opens IS NULL OR (max_opens BETWEEN 1 AND 10)"
           )

    create constraint(:letters, :valid_opens_used, check: "opens_used >= 0")

    create table(:letter_access_grants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :letter_id, references(:letters, type: :binary_id, on_delete: :delete_all), null: false
      add :token_hash, :binary, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :revoked_at, :utc_datetime_usec
      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create unique_index(:letter_access_grants, [:token_hash])
    create index(:letter_access_grants, [:letter_id])
    create index(:letter_access_grants, [:expires_at])
  end
end
