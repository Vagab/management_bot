defmodule FinanceChatIntegration.Repo.Migrations.AddObanJobs do
  use Ecto.Migration

  def change do
    Oban.Migration.up(version: 12)
  end
end
