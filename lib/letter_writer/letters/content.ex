defmodule LetterWriter.Letters.Content do
  @moduledoc false

  alias LetterWriter.Letters.Sanitizer

  @allowed_colors %{
    "#3b2416" => "ink-brown",
    "#6f1d2b" => "ink-burgundy",
    "#1f3a5f" => "ink-blue",
    "#26382a" => "ink-green"
  }
  @allowed_alignments ~w(left center right justify)

  def prepare(json) when is_binary(json) do
    with {:ok, document} <- Jason.decode(json),
         :ok <- valid_document?(document),
         {:ok, html, text} <- render_node(document),
         :ok <- validate_length(text) do
      {:ok,
       %{
         "version" => 1,
         "document" => document,
         "html" => Sanitizer.sanitize(html)
       }}
    else
      _ -> {:error, "contains unsupported or malformed formatting"}
    end
  end

  def prepare(_), do: {:error, "is missing"}

  defp valid_document?(%{"type" => "doc", "content" => content}) when is_list(content), do: :ok
  defp valid_document?(_), do: :error

  defp validate_length(text) do
    length = text |> String.trim() |> String.length()

    cond do
      length == 0 -> {:error, :empty}
      length > 20_000 -> {:error, :too_long}
      true -> :ok
    end
  end

  defp render_node(%{"type" => "doc", "content" => content}), do: render_children(content)

  defp render_node(%{"type" => "paragraph"} = node) do
    wrap_with_content("p", alignment_class(node), Map.get(node, "content", []))
  end

  defp render_node(%{"type" => "heading", "attrs" => %{"level" => level}} = node)
       when level in 1..3 do
    wrap_with_content("h#{level}", alignment_class(node), Map.get(node, "content", []))
  end

  defp render_node(%{"type" => "blockquote"} = node),
    do: wrap_with_content("blockquote", "", Map.get(node, "content", []))

  defp render_node(%{"type" => "bulletList"} = node),
    do: wrap_with_content("ul", "", Map.get(node, "content", []))

  defp render_node(%{"type" => "orderedList"} = node),
    do: wrap_with_content("ol", "", Map.get(node, "content", []))

  defp render_node(%{"type" => "listItem"} = node),
    do: wrap_with_content("li", "", Map.get(node, "content", []))

  defp render_node(%{"type" => "hardBreak"}), do: {:ok, "<br>", "\n"}
  defp render_node(%{"type" => "horizontalRule"}), do: {:ok, "<hr>", "\n"}

  defp render_node(%{"type" => "text", "text" => text} = node) when is_binary(text) do
    html = text |> escape() |> apply_marks(Map.get(node, "marks", []))
    {:ok, html, text}
  end

  defp render_node(_), do: {:error, :unsupported_node}

  defp render_children(children) when is_list(children) do
    Enum.reduce_while(children, {:ok, "", ""}, fn node, {:ok, html, text} ->
      case render_node(node) do
        {:ok, child_html, child_text} ->
          {:cont, {:ok, html <> child_html, text <> child_text <> "\n"}}

        error ->
          {:halt, error}
      end
    end)
  end

  defp render_children(_), do: {:error, :invalid_children}

  defp wrap_with_content(tag, class, content) do
    with {:ok, html, text} <- render_children(content) do
      class_attr = if class == "", do: "", else: ~s( class="#{class}")
      {:ok, "<#{tag}#{class_attr}>#{html}</#{tag}>", text}
    end
  end

  defp alignment_class(%{"attrs" => %{"textAlign" => alignment}})
       when alignment in @allowed_alignments,
       do: "align-#{alignment}"

  defp alignment_class(_), do: ""

  defp apply_marks(html, marks) when is_list(marks) do
    Enum.reduce(marks, html, fn
      %{"type" => "bold"}, acc -> "<strong>#{acc}</strong>"
      %{"type" => "italic"}, acc -> "<em>#{acc}</em>"
      %{"type" => "underline"}, acc -> "<u>#{acc}</u>"
      %{"type" => "strike"}, acc -> "<del>#{acc}</del>"
      %{"type" => "textStyle", "attrs" => %{"color" => color}}, acc -> color_mark(acc, color)
      %{"type" => "link", "attrs" => %{"href" => href}}, acc -> link_mark(acc, href)
      _, acc -> acc
    end)
  end

  defp apply_marks(html, _), do: html

  defp color_mark(html, color) do
    case Map.get(@allowed_colors, String.downcase(color)) do
      nil -> html
      class -> ~s(<span class="#{class}">#{html}</span>)
    end
  end

  defp link_mark(html, href) do
    case URI.parse(href) do
      %URI{scheme: scheme} when scheme in ["http", "https", "mailto"] ->
        ~s(<a href="#{escape(href)}" target="_blank" rel="nofollow noopener noreferrer">#{html}</a>)

      _ ->
        html
    end
  end

  defp escape(value) do
    value
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
