defmodule FinanceChatIntegration.Repo.Migrations.CreateInstructions do
  use Ecto.Migration

  def change do
    create table(:instructions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :description, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:instructions, [:user_id])
  end
end
