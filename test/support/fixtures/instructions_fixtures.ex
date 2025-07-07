defmodule FinanceChatIntegration.InstructionsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FinanceChatIntegration.Instructions` context.
  """

  @doc """
  Generate a instruction.
  """
  def instruction_fixture(attrs \\ %{}) do
    {:ok, instruction} =
      attrs
      |> Enum.into(%{
        description: "some description"
      })
      |> FinanceChatIntegration.Instructions.create_instruction()

    instruction
  end
end
