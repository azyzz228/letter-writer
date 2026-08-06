defmodule LetterWriter.Repo do
  use Ecto.Repo,
    otp_app: :letter_writer,
    adapter: Ecto.Adapters.Postgres
end
