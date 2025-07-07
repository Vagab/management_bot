defmodule FinanceChatIntegration.Repo.Migrations.AddGoogleOauthTokensToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :google_access_token, :text
      add :google_refresh_token, :text
      add :google_token_expires_at, :naive_datetime
      add :google_token_scope, :string
    end
  end
end
