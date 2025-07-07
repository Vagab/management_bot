defmodule FinanceChatIntegration.Instructions.Instruction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "instructions" do
    field :description, :string

    belongs_to :user, FinanceChatIntegration.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(instruction, attrs) do
    instruction
    |> cast(attrs, [:description, :user_id])
    |> validate_required([:description, :user_id])
  end
end
