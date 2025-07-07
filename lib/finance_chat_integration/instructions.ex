defmodule FinanceChatIntegration.Instructions do
  @moduledoc """
  The Instructions context.
  """

  import Ecto.Query, warn: false
  alias FinanceChatIntegration.Repo

  alias FinanceChatIntegration.Instructions.Instruction

  @doc """
  Returns the list of instructions for a user.
  """
  def list_instructions(user_id) do
    Instruction
    |> where([i], i.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Gets a single instruction for a user.
  """
  def get_instruction(user_id, id) do
    Instruction
    |> where([i], i.user_id == ^user_id and i.id == ^id)
    |> Repo.one()
  end

  @doc """
  Creates a instruction.
  """
  def create_instruction(attrs \\ %{}) do
    %Instruction{}
    |> Instruction.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a instruction.
  """
  def update_instruction(%Instruction{} = instruction, attrs) do
    instruction
    |> Instruction.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a instruction.
  """
  def delete_instruction(%Instruction{} = instruction) do
    Repo.delete(instruction)
  end
end
