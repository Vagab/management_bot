defmodule FinanceChatIntegration.Chat do
  @moduledoc """
  The Chat context.
  """

  import Ecto.Query, warn: false
  alias FinanceChatIntegration.Repo

  alias FinanceChatIntegration.Chat.ChatMessage

  @doc """
  Returns the list of chat messages for a user, ordered by timestamp.
  """
  def list_chat_messages(user_id) do
    ChatMessage
    |> where([c], c.user_id == ^user_id)
    |> order_by([c], c.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets recent chat messages for a user (last N messages).
  """
  def get_recent_messages(user_id, limit \\ 50) do
    ChatMessage
    |> where([c], c.user_id == ^user_id)
    |> order_by([c], desc: c.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc """
  Creates a chat message.
  """
  def create_chat_message(attrs \\ %{}) do
    %ChatMessage{}
    |> ChatMessage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes all chat messages for a user.
  """
  def delete_chat_history(user_id) do
    ChatMessage
    |> where([c], c.user_id == ^user_id)
    |> Repo.delete_all()
  end
end
