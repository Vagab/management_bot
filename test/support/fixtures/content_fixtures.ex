defmodule FinanceChatIntegration.ContentFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FinanceChatIntegration.Content` context.
  """

  @doc """
  Generate a content_chunk.
  """
  def content_chunk_fixture(attrs \\ %{}) do
    {:ok, content_chunk} =
      attrs
      |> Enum.into(%{
        content: "some content",
        source: "some source"
      })
      |> FinanceChatIntegration.Content.create_content_chunk()

    content_chunk
  end
end
