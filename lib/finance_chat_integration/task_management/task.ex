defmodule FinanceChatIntegration.TaskManagement.Task do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tasks" do
    field :description, :string

    field :status, Ecto.Enum,
      values: [:in_progress, :completed, :failed, :waiting],
      default: :in_progress

    field :context, :map, default: %{}

    belongs_to :user, FinanceChatIntegration.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(task, attrs) do
    task
    |> cast(attrs, [:description, :status, :context, :user_id])
    |> validate_required([:description, :user_id])
    |> validate_inclusion(:status, [:in_progress, :completed, :failed, :waiting])
  end
end
