defmodule FinanceChatIntegration.Chat.ChatMessage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_messages" do
    field :role, Ecto.Enum, values: [:user, :assistant]

    field :content, :string

    belongs_to :user, FinanceChatIntegration.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(chat_message, attrs) do
    chat_message
    |> cast(attrs, [:role, :content, :user_id])
    |> validate_required([:role, :content, :user_id])
    |> validate_inclusion(:role, [:user, :assistant])
  end
end
