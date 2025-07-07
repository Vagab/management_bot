defmodule FinanceChatIntegration.Content.ContentChunk do
  use Ecto.Schema
  import Ecto.Changeset

  schema "content_chunks" do
    field :content, :string
    field :source, :string
    field :embedding, Pgvector.Ecto.Vector

    belongs_to :user, FinanceChatIntegration.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(content_chunk, attrs) do
    content_chunk
    |> cast(attrs, [:content, :source, :user_id])
    |> validate_required([:content, :source, :user_id])
    |> validate_inclusion(:source, ["gmail", "hubspot", "calendar"])
  end

  @doc false
  def embedding_changeset(content_chunk, attrs) do
    content_chunk
    |> cast(attrs, [:embedding])
    |> validate_required([:embedding])
  end
end
