# Sealed

Sealed is a guest-first Phoenix application for writing private, password-locked letters. Writers can limit openings, set an expiry, keep a private management link, and revoke a letter without creating an account.

## Local development

The development and test databases expect PostgreSQL on port `5440`. The project container can be created once with Podman:

```sh
podman run -d \
  --name letter_writer_postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5440:5432 \
  -v letter_writer_postgres_data:/var/lib/postgresql \
  docker.io/library/postgres:18.3-trixie
```

On later runs, start it with:

```sh
podman start letter_writer_postgres
```

Then install and start the application:

```sh
mix setup
npm install --prefix assets
mix assets.build
mix phx.server
```

Open [http://localhost:4000](http://localhost:4000).

Run the server suite with `mix test`, JavaScript tests with `npm test --prefix assets`, and the full Chromium flow with `npm run test:e2e --prefix assets`. Run all required Phoenix checks with `mix precommit`.

## Container image

Build the production image with Docker or Podman:

```sh
podman build -t letter-writer .
```

Run migrations before starting a newly deployed release:

```sh
podman run --rm \
  --env-file .env.prod \
  letter-writer \
  /app/bin/letter_writer eval 'LetterWriter.Release.migrate()'
```

Then start the web application:

```sh
podman run --rm \
  --name letter-writer \
  --env-file .env.prod \
  -p 4000:4000 \
  letter-writer
```

The image runs as an unprivileged user and contains only the compiled release and its runtime libraries. It expects PostgreSQL to be reachable through `DATABASE_URL`; when the database runs in another container, use a shared Podman network rather than `localhost`.

## Runtime configuration

Production requires:

- `DATABASE_URL`
- `SECRET_KEY_BASE`
- `LETTER_ENCRYPTION_KEY`, a base64-encoded 32-byte key
- `PHX_HOST`

Generate the encryption key with `openssl rand -base64 32`. The encryption key must be stored separately from PostgreSQL and backed up securely; losing it makes existing letters unreadable.

Optional database overrides for development and tests are `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_PORT`.

## Privacy model

- Passwords use Argon2id and are never stored directly.
- Letter payloads are encrypted with AES-GCM before reaching PostgreSQL.
- Rich text is reconstructed from an allowlisted Tiptap JSON document and sanitized server-side.
- Reading grants are random, hashed, path-scoped, and valid for 30 minutes.
- Closed letters are scheduled for physical deletion after 30 days.
- The server handles plaintext during sealing and reading; this is server-side protection, not end-to-end encryption.
- Opening limits cannot prevent screenshots, copying, or photography once a letter is displayed.
