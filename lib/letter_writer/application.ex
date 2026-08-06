defmodule LetterWriter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LetterWriterWeb.Telemetry,
      LetterWriter.Repo,
      LetterWriter.Vault,
      {LetterWriter.RateLimit, clean_period: :timer.minutes(5)},
      {Oban, Application.fetch_env!(:letter_writer, Oban)},
      {DNSCluster, query: Application.get_env(:letter_writer, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LetterWriter.PubSub},
      # Start a worker by calling: LetterWriter.Worker.start_link(arg)
      # {LetterWriter.Worker, arg},
      # Start to serve requests, typically the last entry
      LetterWriterWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LetterWriter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LetterWriterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
