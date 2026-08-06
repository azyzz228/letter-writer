defmodule LetterWriter.Letters do
  @moduledoc """
  The boundary for sealing, unlocking, reading, and revoking private letters.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias LetterWriter.Letters.{AccessGrant, Content, ExpiryWorker, Letter, SealForm}
  alias LetterWriter.{RateLimit, Repo}

  @grant_lifetime 30 * 60

  def change_seal_form(form \\ SealForm.default(), attrs \\ %{}) do
    SealForm.changeset(form, attrs)
  end

  def seal_letter(attrs) do
    changeset = SealForm.changeset(SealForm.default(), attrs)

    with {:ok, form} <- Ecto.Changeset.apply_action(changeset, :insert),
         {:ok, content} <- Content.prepare(form.body_json) do
      do_seal_letter(form, content)
    else
      {:error, %Ecto.Changeset{} = invalid_changeset} ->
        {:error, invalid_changeset}

      {:error, message} ->
        {:error, Ecto.Changeset.add_error(changeset, :body_json, message)}
    end
  end

  def check_seal_rate(ip) do
    with {:allow, _} <- RateLimit.hit("seal:burst:#{ip}", :timer.minutes(1), 2),
         {:allow, _} <- RateLimit.hit("seal:hour:#{ip}", :timer.hours(1), 5) do
      :ok
    else
      {:deny, retry_after} -> {:error, retry_after}
    end
  end

  def check_unlock_rate(ip, letter_id) do
    with {:allow, _} <-
           RateLimit.hit("unlock:letter:#{ip}:#{letter_id}", :timer.minutes(10), 10),
         {:allow, _} <- RateLimit.hit("unlock:global:#{ip}", :timer.hours(1), 100) do
      :ok
    else
      {:deny, retry_after} -> {:error, retry_after}
    end
  end

  def public_status(id) do
    case get_letter(id) do
      nil -> :not_found
      letter -> availability(letter, DateTime.utc_now())
    end
  end

  def unlock_letter(id, password) when is_binary(password) do
    case get_letter(id) do
      nil ->
        Argon2.no_user_verify()
        {:error, :unlock_failed}

      letter ->
        if availability(letter, DateTime.utc_now()) == :sealed and
             Argon2.verify_pass(password, letter.password_hash) do
          issue_grant(letter.id)
        else
          {:error, :unlock_failed}
        end
    end
  end

  def unlock_letter(_id, _password), do: {:error, :unlock_failed}

  def get_letter_for_grant(id, token) when is_binary(token) do
    now = DateTime.utc_now()

    with {:ok, letter_id} <- Ecto.UUID.cast(id),
         token_hash <- token_hash(token),
         %AccessGrant{letter: %Letter{} = letter} <-
           Repo.one(
             from grant in AccessGrant,
               join: letter in assoc(grant, :letter),
               where:
                 grant.letter_id == ^letter_id and grant.token_hash == ^token_hash and
                   is_nil(grant.revoked_at) and grant.expires_at > ^now and
                   not is_nil(letter.payload),
               select: %{grant | letter: letter}
           ),
         false <- letter.closed_reason == :revoked,
         {:ok, payload} <- Jason.decode(letter.payload) do
      {:ok, payload}
    else
      _ -> {:error, :invalid_grant}
    end
  end

  def get_letter_for_grant(_id, _token), do: {:error, :invalid_grant}

  def get_management_status(id, token) when is_binary(token) do
    with %Letter{} = letter <- get_managed_letter(id, token) do
      {:ok, status_map(letter)}
    else
      _ -> {:error, :not_found}
    end
  end

  def get_management_status(_id, _token), do: {:error, :not_found}

  def revoke_letter(id, token) when is_binary(token) do
    now = DateTime.utc_now()

    Multi.new()
    |> Multi.run(:letter, fn repo, _changes ->
      case get_managed_letter(id, token, repo, lock: "FOR UPDATE") do
        nil -> {:error, :not_found}
        letter -> {:ok, letter}
      end
    end)
    |> Multi.update(:revoke, fn %{letter: letter} ->
      letter
      |> Letter.close_changeset(:revoked, now)
      |> Ecto.Changeset.force_change(:purge_at, DateTime.add(now, 30, :day))
    end)
    |> Multi.update_all(
      :revoke_grants,
      fn %{letter: letter} ->
        from grant in AccessGrant,
          where: grant.letter_id == ^letter.id and is_nil(grant.revoked_at),
          update: [set: [revoked_at: ^now]]
      end,
      []
    )
    |> Repo.transact()
    |> case do
      {:ok, %{revoke: letter}} ->
        schedule_purge(letter)
        :telemetry.execute([:letter_writer, :letters, :revoked], %{count: 1})
        {:ok, status_map(letter)}

      {:error, _operation, reason, _changes} ->
        {:error, reason}
    end
  end

  def revoke_letter(_id, _token), do: {:error, :not_found}

  def expire_letter(id) do
    now = DateTime.utc_now()

    Repo.transact(fn ->
      case Repo.one(from letter in Letter, where: letter.id == ^id, lock: "FOR UPDATE") do
        %Letter{closed_at: nil, expires_at: expires_at} = letter when not is_nil(expires_at) ->
          if DateTime.compare(expires_at, now) != :gt do
            letter = letter |> Letter.close_changeset(:expired, now) |> Repo.update!()
            {:ok, {:expired, letter}}
          else
            {:ok, :early}
          end

        _ ->
          {:ok, :noop}
      end
    end)
    |> case do
      {:ok, {:expired, letter}} ->
        schedule_purge(letter)
        :telemetry.execute([:letter_writer, :letters, :expired], %{count: 1})
        :ok

      _ ->
        :ok
    end
  end

  def purge_letter(id) do
    now = DateTime.utc_now()

    from(letter in Letter,
      where: letter.id == ^id and not is_nil(letter.purge_at) and letter.purge_at <= ^now
    )
    |> Repo.delete_all()

    :ok
  end

  def grant_cookie_name(id), do: "letter_grant_#{id}"
  def grant_lifetime, do: @grant_lifetime

  defp do_seal_letter(form, content) do
    management_token = random_token()

    payload =
      content
      |> Map.put("to", form.to_name)
      |> Map.put("from", form.from_name)
      |> Map.put("title", form.title)
      |> Jason.encode!()

    attrs = %{
      payload: payload,
      password_hash: Argon2.hash_pwd_salt(form.password),
      management_token_hash: token_hash(management_token),
      max_opens: if(form.unlimited, do: nil, else: form.max_opens),
      expires_at: if(form.never_expires, do: nil, else: form.expires_at)
    }

    case %Letter{} |> Letter.create_changeset(attrs) |> Repo.insert() do
      {:ok, letter} ->
        schedule_expiry(letter)
        :telemetry.execute([:letter_writer, :letters, :sealed], %{count: 1})
        {:ok, %{letter: letter, management_token: management_token}}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp issue_grant(id) do
    now = DateTime.utc_now()
    raw_token = random_token()

    result =
      Repo.transact(fn ->
        letter = Repo.one(from letter in Letter, where: letter.id == ^id, lock: "FOR UPDATE")

        if letter && availability(letter, now) == :sealed do
          opens_used = letter.opens_used + 1
          exhausted? = not is_nil(letter.max_opens) and opens_used >= letter.max_opens

          changes = %{
            opens_used: opens_used,
            first_opened_at: letter.first_opened_at || now,
            last_opened_at: now
          }

          changes =
            if exhausted? do
              Map.merge(changes, %{
                closed_at: now,
                closed_reason: :exhausted,
                purge_at: DateTime.add(now, 30, :day)
              })
            else
              changes
            end

          letter = letter |> Ecto.Changeset.change(changes) |> Repo.update!()

          grant =
            %AccessGrant{letter_id: letter.id}
            |> AccessGrant.changeset(%{
              token_hash: token_hash(raw_token),
              expires_at: DateTime.add(now, @grant_lifetime, :second)
            })
            |> Repo.insert!()

          {:ok, {letter, grant}}
        else
          Repo.rollback(:unavailable)
        end
      end)

    case result do
      {:ok, {letter, grant}} ->
        if letter.closed_reason == :exhausted, do: schedule_purge(letter)

        :telemetry.execute([:letter_writer, :letters, :unlocked], %{count: 1})
        {:ok, %{token: raw_token, expires_at: grant.expires_at}}

      _ ->
        {:error, :unlock_failed}
    end
  end

  defp availability(%Letter{closed_reason: :revoked}, _now), do: :unavailable
  defp availability(%Letter{closed_reason: :exhausted}, _now), do: :unavailable
  defp availability(%Letter{closed_reason: :expired}, _now), do: :unavailable

  defp availability(%Letter{expires_at: expires_at}, now) when not is_nil(expires_at) do
    if DateTime.compare(expires_at, now) == :gt, do: :sealed, else: :unavailable
  end

  defp availability(%Letter{}, _now), do: :sealed

  defp status_map(letter) do
    status =
      cond do
        letter.closed_reason == :revoked ->
          :revoked

        letter.closed_reason == :exhausted ->
          :exhausted

        letter.closed_reason == :expired ->
          :expired

        letter.expires_at && DateTime.compare(letter.expires_at, DateTime.utc_now()) != :gt ->
          :expired

        true ->
          :sealed
      end

    %{
      id: letter.id,
      status: status,
      opens_used: letter.opens_used,
      max_opens: letter.max_opens,
      first_opened_at: letter.first_opened_at,
      last_opened_at: letter.last_opened_at,
      expires_at: letter.expires_at,
      inserted_at: letter.inserted_at,
      purge_at: letter.purge_at
    }
  end

  defp get_letter(id) do
    with {:ok, id} <- Ecto.UUID.cast(id), do: Repo.get(Letter, id)
  end

  defp get_managed_letter(id, token, repo \\ Repo, opts \\ []) do
    with {:ok, id} <- Ecto.UUID.cast(id) do
      query =
        from letter in Letter,
          where: letter.id == ^id and letter.management_token_hash == ^token_hash(token)

      query = if Keyword.get(opts, :lock), do: lock(query, "FOR UPDATE"), else: query
      repo.one(query)
    else
      _ -> nil
    end
  end

  defp schedule_expiry(%Letter{expires_at: nil}), do: :ok

  defp schedule_expiry(letter) do
    %{letter_id: letter.id, action: "expire"}
    |> ExpiryWorker.new(scheduled_at: letter.expires_at)
    |> Oban.insert()

    :ok
  end

  defp schedule_purge(%Letter{purge_at: nil}), do: :ok

  defp schedule_purge(letter) do
    %{letter_id: letter.id, action: "purge"}
    |> ExpiryWorker.new(scheduled_at: letter.purge_at)
    |> Oban.insert()

    :ok
  end

  defp random_token do
    32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end

  defp token_hash(token), do: :crypto.hash(:sha256, token)
end
