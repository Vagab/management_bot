defmodule FinanceChatIntegration.InstructionsTest do
  use FinanceChatIntegration.DataCase

  alias FinanceChatIntegration.Instructions

  describe "instructions" do
    alias FinanceChatIntegration.Instructions.Instruction

    import FinanceChatIntegration.InstructionsFixtures

    @invalid_attrs %{description: nil}

    test "list_instructions/0 returns all instructions" do
      instruction = instruction_fixture()
      assert Instructions.list_instructions() == [instruction]
    end

    test "get_instruction!/1 returns the instruction with given id" do
      instruction = instruction_fixture()
      assert Instructions.get_instruction!(instruction.id) == instruction
    end

    test "create_instruction/1 with valid data creates a instruction" do
      valid_attrs = %{description: "some description"}

      assert {:ok, %Instruction{} = instruction} = Instructions.create_instruction(valid_attrs)
      assert instruction.description == "some description"
    end

    test "create_instruction/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Instructions.create_instruction(@invalid_attrs)
    end

    test "update_instruction/2 with valid data updates the instruction" do
      instruction = instruction_fixture()
      update_attrs = %{description: "some updated description"}

      assert {:ok, %Instruction{} = instruction} = Instructions.update_instruction(instruction, update_attrs)
      assert instruction.description == "some updated description"
    end

    test "update_instruction/2 with invalid data returns error changeset" do
      instruction = instruction_fixture()
      assert {:error, %Ecto.Changeset{}} = Instructions.update_instruction(instruction, @invalid_attrs)
      assert instruction == Instructions.get_instruction!(instruction.id)
    end

    test "delete_instruction/1 deletes the instruction" do
      instruction = instruction_fixture()
      assert {:ok, %Instruction{}} = Instructions.delete_instruction(instruction)
      assert_raise Ecto.NoResultsError, fn -> Instructions.get_instruction!(instruction.id) end
    end

    test "change_instruction/1 returns a instruction changeset" do
      instruction = instruction_fixture()
      assert %Ecto.Changeset{} = Instructions.change_instruction(instruction)
    end
  end
end
