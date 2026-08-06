defmodule LetterWriter.Encrypted.Binary do
  @moduledoc false
  use Cloak.Ecto.Binary, vault: LetterWriter.Vault
end
