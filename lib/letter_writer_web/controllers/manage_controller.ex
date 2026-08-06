defmodule LetterWriterWeb.ManageController do
  use LetterWriterWeb, :controller

  alias LetterWriter.Letters

  def show(conn, %{"id" => id, "token" => token}) do
    case Letters.get_management_status(id, token) do
      {:ok, status} ->
        render(conn, :show,
          status: status,
          management_token: token,
          page_title: "Manage your letter"
        )

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> render(:not_found, page_title: "Management link unavailable")
    end
  end

  def revoke(conn, %{"id" => id, "token" => token}) do
    case Letters.revoke_letter(id, token) do
      {:ok, _status} ->
        conn
        |> put_flash(:info, "The letter has been permanently recalled.")
        |> redirect(to: ~p"/manage/#{id}/#{token}")

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> render(:not_found, page_title: "Management link unavailable")
    end
  end
end
