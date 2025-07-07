defmodule FinanceChatIntegration.TaskManagement do
  @moduledoc """
  The TaskManagement context.
  """

  import Ecto.Query, warn: false
  alias FinanceChatIntegration.Repo

  alias FinanceChatIntegration.TaskManagement.Task

  @doc """
  Returns the list of tasks for a user.
  """
  def list_tasks(user_id) do
    Task
    |> where([t], t.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Returns tasks by status for a user.
  """
  def list_tasks_by_status(user_id, status) do
    Task
    |> where([t], t.user_id == ^user_id and t.status == ^status)
    |> Repo.all()
  end

  @doc """
  Gets a single task for a user.
  """
  def get_task(user_id, id) do
    Task
    |> where([t], t.user_id == ^user_id and t.id == ^id)
    |> Repo.one()
  end

  @doc """
  Creates a task.
  """
  def create_task(attrs \\ %{}) do
    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a task.
  """
  def update_task(%Task{} = task, attrs) do
    task
    |> Task.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a task.
  """
  def delete_task(%Task{} = task) do
    Repo.delete(task)
  end
end
