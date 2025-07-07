defmodule FinanceChatIntegration.ContentTest do
  use FinanceChatIntegration.DataCase

  alias FinanceChatIntegration.Content

  describe "content_chunks" do
    alias FinanceChatIntegration.Content.ContentChunk

    import FinanceChatIntegration.ContentFixtures

    @invalid_attrs %{source: nil, content: nil}

    test "list_content_chunks/0 returns all content_chunks" do
      content_chunk = content_chunk_fixture()
      assert Content.list_content_chunks() == [content_chunk]
    end

    test "get_content_chunk!/1 returns the content_chunk with given id" do
      content_chunk = content_chunk_fixture()
      assert Content.get_content_chunk!(content_chunk.id) == content_chunk
    end

    test "create_content_chunk/1 with valid data creates a content_chunk" do
      valid_attrs = %{source: "some source", content: "some content"}

      assert {:ok, %ContentChunk{} = content_chunk} = Content.create_content_chunk(valid_attrs)
      assert content_chunk.source == "some source"
      assert content_chunk.content == "some content"
    end

    test "create_content_chunk/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Content.create_content_chunk(@invalid_attrs)
    end

    test "update_content_chunk/2 with valid data updates the content_chunk" do
      content_chunk = content_chunk_fixture()
      update_attrs = %{source: "some updated source", content: "some updated content"}

      assert {:ok, %ContentChunk{} = content_chunk} = Content.update_content_chunk(content_chunk, update_attrs)
      assert content_chunk.source == "some updated source"
      assert content_chunk.content == "some updated content"
    end

    test "update_content_chunk/2 with invalid data returns error changeset" do
      content_chunk = content_chunk_fixture()
      assert {:error, %Ecto.Changeset{}} = Content.update_content_chunk(content_chunk, @invalid_attrs)
      assert content_chunk == Content.get_content_chunk!(content_chunk.id)
    end

    test "delete_content_chunk/1 deletes the content_chunk" do
      content_chunk = content_chunk_fixture()
      assert {:ok, %ContentChunk{}} = Content.delete_content_chunk(content_chunk)
      assert_raise Ecto.NoResultsError, fn -> Content.get_content_chunk!(content_chunk.id) end
    end

    test "change_content_chunk/1 returns a content_chunk changeset" do
      content_chunk = content_chunk_fixture()
      assert %Ecto.Changeset{} = Content.change_content_chunk(content_chunk)
    end
  end
end
