defmodule FinanceChatIntegration.Content do
  @moduledoc """
  The Content context.
  """

  import Ecto.Query, warn: false
  alias FinanceChatIntegration.Repo

  alias FinanceChatIntegration.Content.ContentChunk

  @doc """
  Returns the list of content_chunks.

  ## Examples

      iex> list_content_chunks()
      [%ContentChunk{}, ...]

  """
  def list_content_chunks do
    Repo.all(ContentChunk)
  end

  @doc """
  Gets a single content_chunk.

  Raises `Ecto.NoResultsError` if the Content chunk does not exist.

  ## Examples

      iex> get_content_chunk!(123)
      %ContentChunk{}

      iex> get_content_chunk!(456)
      ** (Ecto.NoResultsError)

  """
  def get_content_chunk!(id), do: Repo.get!(ContentChunk, id)

  @doc """
  Creates a content_chunk.

  ## Examples

      iex> create_content_chunk(%{field: value})
      {:ok, %ContentChunk{}}

      iex> create_content_chunk(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_content_chunk(attrs \\ %{}) do
    %ContentChunk{}
    |> ContentChunk.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a content_chunk.

  ## Examples

      iex> update_content_chunk(content_chunk, %{field: new_value})
      {:ok, %ContentChunk{}}

      iex> update_content_chunk(content_chunk, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_content_chunk(%ContentChunk{} = content_chunk, attrs) do
    content_chunk
    |> ContentChunk.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a content_chunk.

  ## Examples

      iex> delete_content_chunk(content_chunk)
      {:ok, %ContentChunk{}}

      iex> delete_content_chunk(content_chunk)
      {:error, %Ecto.Changeset{}}

  """
  def delete_content_chunk(%ContentChunk{} = content_chunk) do
    Repo.delete(content_chunk)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking content_chunk changes.

  ## Examples

      iex> change_content_chunk(content_chunk)
      %Ecto.Changeset{data: %ContentChunk{}}

  """
  def change_content_chunk(%ContentChunk{} = content_chunk, attrs \\ %{}) do
    ContentChunk.changeset(content_chunk, attrs)
  end
end
