defmodule FinanceChatIntegration.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :description, :text, null: false
      add :status, :string, default: "in_progress", null: false
      add :context, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:tasks, [:user_id])
    create index(:tasks, [:status])
    create index(:tasks, [:user_id, :status])
  end
end
