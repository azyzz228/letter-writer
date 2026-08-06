defmodule LetterWriterWeb.ManageHTML do
  use LetterWriterWeb, :html

  embed_templates "manage_html/*"

  def format_datetime(nil), do: "Not yet"

  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%d %b %Y · %H:%M UTC")
  end

  def status_label(:sealed), do: "Sealed & waiting"
  def status_label(:exhausted), do: "Opening limit reached"
  def status_label(:expired), do: "Expired"
  def status_label(:revoked), do: "Recalled"
end
