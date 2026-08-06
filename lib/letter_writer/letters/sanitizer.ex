defmodule LetterWriter.Letters.Sanitizer do
  @moduledoc false
  use HtmlSanitizeEx

  allow_tag_with_uri_attributes("a", ["href"], ["http", "https", "mailto"])
  allow_tag_with_these_attributes("a", ["target", "rel", "title"])
  allow_tag_with_these_attributes("blockquote", ["class"])
  allow_tag_with_these_attributes("br", [])
  allow_tag_with_these_attributes("del", [])
  allow_tag_with_these_attributes("em", [])
  allow_tag_with_these_attributes("h1", ["class"])
  allow_tag_with_these_attributes("h2", ["class"])
  allow_tag_with_these_attributes("h3", ["class"])
  allow_tag_with_these_attributes("hr", [])
  allow_tag_with_these_attributes("li", [])
  allow_tag_with_these_attributes("ol", [])
  allow_tag_with_these_attributes("p", ["class"])
  allow_tag_with_these_attributes("span", ["class"])
  allow_tag_with_these_attributes("strong", [])
  allow_tag_with_these_attributes("u", [])
  allow_tag_with_these_attributes("ul", [])
end
