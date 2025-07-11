defmodule FinanceChatIntegration.ChatTest do
  use FinanceChatIntegration.DataCase

  alias FinanceChatIntegration.Chat

  describe "chat_messages" do
    alias FinanceChatIntegration.Chat.ChatMessage

    import FinanceChatIntegration.ChatFixtures

    @invalid_attrs %{role: nil, content: nil}

    test "list_chat_messages/0 returns all chat_messages" do
      chat_message = chat_message_fixture()
      assert Chat.list_chat_messages() == [chat_message]
    end

    test "get_chat_message!/1 returns the chat_message with given id" do
      chat_message = chat_message_fixture()
      assert Chat.get_chat_message!(chat_message.id) == chat_message
    end

    test "create_chat_message/1 with valid data creates a chat_message" do
      valid_attrs = %{role: "some role", content: "some content"}

      assert {:ok, %ChatMessage{} = chat_message} = Chat.create_chat_message(valid_attrs)
      assert chat_message.role == "some role"
      assert chat_message.content == "some content"
    end

    test "create_chat_message/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Chat.create_chat_message(@invalid_attrs)
    end

    test "update_chat_message/2 with valid data updates the chat_message" do
      chat_message = chat_message_fixture()
      update_attrs = %{role: "some updated role", content: "some updated content"}

      assert {:ok, %ChatMessage{} = chat_message} = Chat.update_chat_message(chat_message, update_attrs)
      assert chat_message.role == "some updated role"
      assert chat_message.content == "some updated content"
    end

    test "update_chat_message/2 with invalid data returns error changeset" do
      chat_message = chat_message_fixture()
      assert {:error, %Ecto.Changeset{}} = Chat.update_chat_message(chat_message, @invalid_attrs)
      assert chat_message == Chat.get_chat_message!(chat_message.id)
    end

    test "delete_chat_message/1 deletes the chat_message" do
      chat_message = chat_message_fixture()
      assert {:ok, %ChatMessage{}} = Chat.delete_chat_message(chat_message)
      assert_raise Ecto.NoResultsError, fn -> Chat.get_chat_message!(chat_message.id) end
    end

    test "change_chat_message/1 returns a chat_message changeset" do
      chat_message = chat_message_fixture()
      assert %Ecto.Changeset{} = Chat.change_chat_message(chat_message)
    end
  end
end
