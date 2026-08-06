defmodule LetterWriter.Letters.SealForm do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :to_name, :string
    field :from_name, :string
    field :title, :string
    field :body_json, :string
    field :password, :string, redact: true
    field :password_confirmation, :string, redact: true
    field :max_opens, :integer, default: 1
    field :unlimited, :boolean, default: false
    field :expires_at, :utc_datetime
    field :never_expires, :boolean, default: false
  end

  def changeset(form, attrs \\ %{}) do
    form
    |> cast(attrs, [
      :to_name,
      :from_name,
      :title,
      :body_json,
      :password,
      :password_confirmation,
      :max_opens,
      :unlimited,
      :expires_at,
      :never_expires
    ])
    |> update_change(:to_name, &clean/1)
    |> update_change(:from_name, &clean/1)
    |> update_change(:title, &clean/1)
    |> validate_length(:to_name, max: 80)
    |> validate_length(:from_name, max: 80)
    |> validate_length(:title, max: 120)
    |> validate_required([:body_json, :password, :password_confirmation])
    |> validate_length(:password, min: 8, max: 128)
    |> validate_confirmation(:password, required: true)
    |> validate_open_limit()
    |> validate_expiry()
  end

  def default do
    %__MODULE__{
      max_opens: 1,
      expires_at:
        DateTime.utc_now()
        |> DateTime.add(30, :day)
        |> DateTime.truncate(:second)
    }
  end

  defp clean(nil), do: nil

  defp clean(value) do
    case String.trim(value) do
      "" -> nil
      cleaned -> cleaned
    end
  end

  defp validate_open_limit(changeset) do
    if get_field(changeset, :unlimited) do
      changeset
    else
      changeset
      |> validate_required([:max_opens])
      |> validate_number(:max_opens, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
    end
  end

  defp validate_expiry(changeset) do
    if get_field(changeset, :never_expires) do
      changeset
    else
      changeset
      |> validate_required([:expires_at])
      |> validate_change(:expires_at, fn :expires_at, expires_at ->
        now = DateTime.utc_now()

        cond do
          DateTime.compare(expires_at, now) != :gt ->
            [expires_at: "must be in the future"]

          DateTime.compare(expires_at, DateTime.add(now, 366, :day)) == :gt ->
            [expires_at: "must be within one year"]

          true ->
            []
        end
      end)
    end
  end
end
