defmodule FinanceChatIntegration.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, null: false
      add :content, :text, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:chat_messages, [:user_id])
    create index(:chat_messages, [:role])
    create index(:chat_messages, [:user_id, :inserted_at])
  end
end
