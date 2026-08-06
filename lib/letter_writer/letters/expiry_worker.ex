defmodule LetterWriter.Letters.ExpiryWorker do
  use Oban.Worker, queue: :maintenance, max_attempts: 5

  alias LetterWriter.Letters

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"letter_id" => id, "action" => "expire"}}) do
    Letters.expire_letter(id)
  end

  def perform(%Oban.Job{args: %{"letter_id" => id, "action" => "purge"}}) do
    Letters.purge_letter(id)
  end
end
