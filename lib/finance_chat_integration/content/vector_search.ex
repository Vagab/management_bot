defmodule FinanceChatIntegration.Content.VectorSearch do
  @moduledoc """
  Vector search functionality for content chunks using pgvector.
  """

  import Ecto.Query
  alias FinanceChatIntegration.{Content.ContentChunk, Repo}

  @doc """
  Searches for content chunks similar to the given query text.

  ## Parameters
  - `query_embedding`: The embedding vector for the query text
  - `user_id`: The ID of the user to search within
  - `opts`: Options for the search
    - `:limit` - Maximum number of results to return (default: 5)
    - `:source_filter` - Filter by source type ("gmail", "hubspot", "calendar", or nil for all)
    - `:similarity_threshold` - Minimum similarity score (0.0 to 1.0, default: 0.7)

  ## Returns
  A list of content chunks ordered by similarity (most similar first).
  """
  def search_similar(query_embedding, user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)
    source_filter = Keyword.get(opts, :source_filter)
    similarity_threshold = Keyword.get(opts, :similarity_threshold, 0.7)

    query =
      from c in ContentChunk,
        where: c.user_id == ^user_id,
        where: not is_nil(c.embedding),
        select: %{
          id: c.id,
          content: c.content,
          source: c.source,
          inserted_at: c.inserted_at,
          similarity: fragment("1 - (? <=> ?)", c.embedding, ^query_embedding)
        },
        order_by: [asc: fragment("? <=> ?", c.embedding, ^query_embedding)],
        limit: ^limit

    query =
      if source_filter do
        where(query, [c], c.source == ^source_filter)
      else
        query
      end

    query
    |> Repo.all()
    |> Enum.filter(fn chunk -> chunk.similarity >= similarity_threshold end)
  end

  @doc """
  Generates embedding for text content using OpenAI API.

  ## Parameters
  - `text`: The text to generate embedding for

  ## Returns
  {:ok, embedding_vector} or {:error, reason}
  """
  def generate_embedding(text) do
    case OpenAI.embeddings(
           model: "text-embedding-3-small",
           input: text
         ) do
      {:ok, %{data: [%{"embedding" => embedding}]}} ->
        {:ok, embedding}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Creates a content chunk with its embedding.

  ## Parameters
  - `attrs`: Map with content chunk attributes

  ## Returns
  {:ok, content_chunk} or {:error, changeset}
  """
  def create_chunk_with_embedding(attrs) do
    with {:ok, embedding} <- generate_embedding(attrs.content),
         attrs_with_embedding <- Map.put(attrs, :embedding, embedding),
         changeset <- ContentChunk.changeset(%ContentChunk{}, attrs_with_embedding),
         {:ok, chunk} <- Repo.insert(changeset) do
      {:ok, chunk}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Updates the embedding for an existing content chunk.

  ## Parameters
  - `chunk`: The content chunk to update

  ## Returns
  {:ok, updated_chunk} or {:error, reason}
  """
  def update_chunk_embedding(chunk) do
    with {:ok, embedding} <- generate_embedding(chunk.content),
         changeset <- ContentChunk.embedding_changeset(chunk, %{embedding: embedding}),
         {:ok, updated_chunk} <- Repo.update(changeset) do
      {:ok, updated_chunk}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Searches for content chunks and returns formatted results for LLM context.

  ## Parameters
  - `query_text`: The search query text
  - `user_id`: The ID of the user to search within
  - `opts`: Search options (same as search_similar/3)

  ## Returns
  {:ok, formatted_results} or {:error, reason}
  """
  def search_for_context(query_text, user_id, opts \\ []) do
    with {:ok, query_embedding} <- generate_embedding(query_text),
         results <- search_similar(query_embedding, user_id, opts) do
      formatted_results =
        results
        |> Enum.map(fn chunk ->
          %{
            content: chunk.content,
            source: chunk.source,
            similarity: Float.round(chunk.similarity, 3),
            timestamp: chunk.inserted_at
          }
        end)

      {:ok, formatted_results}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
