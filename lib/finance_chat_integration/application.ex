defmodule FinanceChatIntegration.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FinanceChatIntegrationWeb.Telemetry,
      FinanceChatIntegration.Repo,
      {DNSCluster,
       query: Application.get_env(:finance_chat_integration, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FinanceChatIntegration.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: FinanceChatIntegration.Finch},
      # Start Oban for background jobs
      {Oban, Application.fetch_env!(:finance_chat_integration, Oban)},
      # Start a worker by calling: FinanceChatIntegration.Worker.start_link(arg)
      # {FinanceChatIntegration.Worker, arg},
      # Start to serve requests, typically the last entry
      FinanceChatIntegrationWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FinanceChatIntegration.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FinanceChatIntegrationWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
