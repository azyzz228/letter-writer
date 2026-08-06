defmodule Mix.Tasks.Assets.CopyFonts do
  use Mix.Task

  @shortdoc "Copies the self-hosted variable fonts into priv/static"

  @fonts [
    {"caveat", "caveat-cyrillic-ext-wght-normal.woff2"},
    {"caveat", "caveat-cyrillic-wght-normal.woff2"},
    {"caveat", "caveat-latin-wght-normal.woff2"},
    {"cormorant-garamond", "cormorant-garamond-cyrillic-ext-wght-normal.woff2"},
    {"cormorant-garamond", "cormorant-garamond-cyrillic-wght-normal.woff2"},
    {"cormorant-garamond", "cormorant-garamond-latin-wght-normal.woff2"},
    {"eb-garamond", "eb-garamond-cyrillic-ext-wght-normal.woff2"},
    {"eb-garamond", "eb-garamond-cyrillic-wght-normal.woff2"},
    {"eb-garamond", "eb-garamond-latin-wght-normal.woff2"}
  ]

  @impl Mix.Task
  def run(_args) do
    destination = Path.expand("priv/static/fonts")
    File.mkdir_p!(destination)

    Enum.each(@fonts, fn {family, filename} ->
      source = Path.expand("assets/node_modules/@fontsource-variable/#{family}/files/#{filename}")
      File.cp!(source, Path.join(destination, filename))
    end)
  end
end
