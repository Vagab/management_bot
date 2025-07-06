defmodule FinanceChatIntegration.Repo.Migrations.AddOauthFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :provider, :string
      add :provider_uid, :string
    end

    # Create a unique index to ensure a user can only link a provider once
    create unique_index(:users, [:provider, :provider_uid])
  end
end
