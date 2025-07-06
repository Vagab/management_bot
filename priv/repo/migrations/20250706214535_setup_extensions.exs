defmodule FinanceChatIntegration.Repo.Migrations.SetupExtensions do
  use Ecto.Migration

  def change do
    # Enable pgvector extension
    execute "CREATE EXTENSION IF NOT EXISTS vector"
  end
end
