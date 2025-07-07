defmodule FinanceChatIntegration.ChatFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FinanceChatIntegration.Chat` context.
  """

  @doc """
  Generate a chat_message.
  """
  def chat_message_fixture(attrs \\ %{}) do
    {:ok, chat_message} =
      attrs
      |> Enum.into(%{
        content: "some content",
        role: "some role"
      })
      |> FinanceChatIntegration.Chat.create_chat_message()

    chat_message
  end
end
