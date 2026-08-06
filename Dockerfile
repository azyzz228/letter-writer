# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20230612-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.18.4-erlang-27.3.4.3-debian-trixie-20250908-slim

ARG ELIXIR_VERSION=1.19
ARG OTP_VERSION=27.3.4.5
ARG DEBIAN_VERSION=trixie-20260112-slim
ARG NODE_MAJOR=22

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# ============================================================
# Builder stage
# ============================================================
FROM ${BUILDER_IMAGE} AS builder

# Install build dependencies + Node.js via NodeSource
ARG NODE_MAJOR
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential curl git ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV="prod"

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config files before compiling dependencies
# so that any relevant config change triggers a re-compile.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib

# Copy JS/TS project files
# tsconfig.json* uses a glob so the COPY succeeds even if the file is absent
COPY package.json package-lock.json ./
COPY tsconfig.json* ./
COPY assets assets

# Install JS deps and build assets
RUN mix assets.setup

# Compile the Elixir release
RUN mix compile

# Build assets with Vite (client + SSR)
RUN mix assets.deploy

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# ============================================================
# Runner stage
# ============================================================
FROM ${RUNNER_IMAGE}

ARG NODE_MAJOR=22

# Install runtime deps, Node.js (for LiveVue SSR), tini, and locale tools
# in a single layer to minimise redundant apt index fetches
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y --no-install-recommends \
         libstdc++6 openssl libncurses6 locales nodejs tini \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/prod/rel/letter_writer ./

USER nobody

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s \
  CMD curl -f http://localhost:4000/health || exit 1

# tini handles signal forwarding and zombie reaping
ENTRYPOINT ["/usr/bin/tini", "--"]
# Apply pending database migrations before starting the server. `exec` replaces
# the shell with the release process so it receives signals directly from tini.
CMD ["/bin/sh", "-c", "/app/bin/migrate && exec /app/bin/server"]

