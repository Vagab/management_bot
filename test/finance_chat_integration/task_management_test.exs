defmodule FinanceChatIntegration.TaskManagementTest do
  use FinanceChatIntegration.DataCase

  alias FinanceChatIntegration.TaskManagement

  describe "tasks" do
    alias FinanceChatIntegration.TaskManagement.Task

    import FinanceChatIntegration.TaskManagementFixtures

    @invalid_attrs %{status: nil, context: nil, description: nil}

    test "list_tasks/0 returns all tasks" do
      task = task_fixture()
      assert TaskManagement.list_tasks() == [task]
    end

    test "get_task!/1 returns the task with given id" do
      task = task_fixture()
      assert TaskManagement.get_task!(task.id) == task
    end

    test "create_task/1 with valid data creates a task" do
      valid_attrs = %{status: "some status", context: %{}, description: "some description"}

      assert {:ok, %Task{} = task} = TaskManagement.create_task(valid_attrs)
      assert task.status == "some status"
      assert task.context == %{}
      assert task.description == "some description"
    end

    test "create_task/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = TaskManagement.create_task(@invalid_attrs)
    end

    test "update_task/2 with valid data updates the task" do
      task = task_fixture()
      update_attrs = %{status: "some updated status", context: %{}, description: "some updated description"}

      assert {:ok, %Task{} = task} = TaskManagement.update_task(task, update_attrs)
      assert task.status == "some updated status"
      assert task.context == %{}
      assert task.description == "some updated description"
    end

    test "update_task/2 with invalid data returns error changeset" do
      task = task_fixture()
      assert {:error, %Ecto.Changeset{}} = TaskManagement.update_task(task, @invalid_attrs)
      assert task == TaskManagement.get_task!(task.id)
    end

    test "delete_task/1 deletes the task" do
      task = task_fixture()
      assert {:ok, %Task{}} = TaskManagement.delete_task(task)
      assert_raise Ecto.NoResultsError, fn -> TaskManagement.get_task!(task.id) end
    end

    test "change_task/1 returns a task changeset" do
      task = task_fixture()
      assert %Ecto.Changeset{} = TaskManagement.change_task(task)
    end
  end
end
