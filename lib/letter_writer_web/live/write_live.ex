defmodule LetterWriterWeb.WriteLive do
  use LetterWriterWeb, :live_view

  alias LetterWriter.Letters

  @impl true
  def mount(_params, _session, socket) do
    peer_data = get_connect_info(socket, :peer_data) || %{}

    {:ok,
     socket
     |> assign(:page_title, "Write a letter")
     |> assign(:state, :composing)
     |> assign(:peer_ip, format_ip(peer_data[:address]))
     |> assign(:form, to_form(Letters.change_seal_form()))}
  end

  @impl true
  def handle_event("validate", %{"seal_form" => params}, socket) do
    form =
      Letters.change_seal_form(LetterWriter.Letters.SealForm.default(), params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("seal", %{"seal_form" => params}, socket) do
    with :ok <- Letters.check_seal_rate(socket.assigns.peer_ip),
         {:ok, result} <- Letters.seal_letter(params) do
      public_url = LetterWriterWeb.Endpoint.url() <> ~p"/letters/#{result.letter.id}"

      management_url =
        LetterWriterWeb.Endpoint.url() <>
          ~p"/manage/#{result.letter.id}/#{result.management_token}"

      {:noreply,
       socket
       |> assign(:state, :sealed)
       |> assign(:public_url, public_url)
       |> assign(:management_url, management_url)
       |> push_event("letter-sealed", %{})}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(Map.put(changeset, :action, :insert)))}

      {:error, _retry_after} ->
        {:noreply,
         put_flash(socket, :error, "Please wait a little before sealing another letter.")}
    end
  end

  defp format_ip(nil), do: "unknown"
  defp format_ip(address), do: address |> :inet.ntoa() |> to_string()
end
