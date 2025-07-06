defmodule FinanceChatIntegration.Repo do
  use Ecto.Repo,
    otp_app: :finance_chat_integration,
    adapter: Ecto.Adapters.Postgres
end
