defmodule FinanceChatIntegration.TaskManagementFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FinanceChatIntegration.TaskManagement` context.
  """

  @doc """
  Generate a task.
  """
  def task_fixture(attrs \\ %{}) do
    {:ok, task} =
      attrs
      |> Enum.into(%{
        context: %{},
        description: "some description",
        status: "some status"
      })
      |> FinanceChatIntegration.TaskManagement.create_task()

    task
  end
end
