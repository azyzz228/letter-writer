defmodule LetterWriterWeb.PageController do
  use LetterWriterWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
