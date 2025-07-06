defmodule FinanceChatIntegration.Repo.Migrations.AddHubspotTokensToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Access tokens can be long
      add :hubspot_access_token, :text
      add :hubspot_refresh_token, :text
      add :hubspot_token_expires_at, :naive_datetime
    end
  end
end
