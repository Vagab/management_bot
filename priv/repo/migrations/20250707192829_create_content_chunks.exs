defmodule FinanceChatIntegration.Repo.Migrations.CreateContentChunks do
  use Ecto.Migration

  def change do
    create table(:content_chunks) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :content, :text, null: false
      add :source, :string, null: false
      add :embedding, :vector, size: 1536

      timestamps(type: :utc_datetime)
    end

    create index(:content_chunks, [:user_id])
    create index(:content_chunks, [:source])
    create index(:content_chunks, [:user_id, :source])

    # Vector similarity search index using HNSW algorithm
    execute "CREATE INDEX content_chunks_embedding_idx ON content_chunks USING hnsw (embedding vector_cosine_ops)"
  end
end
