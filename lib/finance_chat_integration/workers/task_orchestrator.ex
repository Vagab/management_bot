defmodule FinanceChatIntegration.Workers.TaskOrchestrator do
  @moduledoc """
  Task Orchestrator worker that uses LLM to manage and execute tasks.

  This worker runs periodically to:
  - Collect context (new emails, active tasks, current time)
  - Ask LLM to decide what actions to take
  - Execute LLM's decisions
  """

  use Oban.Worker, queue: :task_orchestration, max_attempts: 3

  alias FinanceChatIntegration.{
    Integrations,
    TaskManagement,
    Accounts,
    LLM
  }

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Starting task orchestration for all users")

    users = Accounts.list_users_with_tokens()

    Enum.each(users, fn user ->
      Logger.info("Processing tasks for user #{user.id}")
      orchestrate_tasks(user)
    end)

    Logger.info("Completed task orchestration for #{length(users)} users")
    :ok
  end

  defp orchestrate_tasks(user) do
    with {:ok, context} <- collect_context(user),
         {:ok, messages} <- build_llm_messages(context) do
      Logger.info(
        "Starting LLM processing for user #{user.id} with context: #{inspect_context_summary(context)}"
      )

      case LLM.process_with_tools(messages, user, temperature: 0.3) do
        {:ok, final_response} ->
          Logger.info("Task orchestration completed for user #{user.id}")
          Logger.info("LLM final response: #{inspect(final_response)}")

          # Log current task statuses after orchestration
          log_task_statuses_after_orchestration(user)
          :ok

        {:error, reason} ->
          Logger.error("Task orchestration failed for user #{user.id}: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, reason} ->
        Logger.error("Failed to prepare orchestration for user #{user.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp collect_context(user) do
    Logger.info("Collecting context for user #{user.id}")

    # Get active tasks
    active_tasks = TaskManagement.list_tasks_by_status(user.id, :in_progress)
    waiting_tasks = TaskManagement.list_tasks_by_status(user.id, :waiting)

    # Get new emails (last 5 minutes)
    fifteen_minutes_ago = DateTime.utc_now() |> DateTime.add(-15, :minute)

    new_emails =
      case fetch_recent_emails(user, fifteen_minutes_ago) do
        {:ok, emails} -> emails
      end

    context = %{
      current_time: DateTime.utc_now(),
      active_tasks: format_tasks_for_llm(active_tasks),
      waiting_tasks: format_tasks_for_llm(waiting_tasks),
      new_emails: format_emails_for_llm(new_emails),
      user_id: user.id
    }

    {:ok, context}
  end

  defp fetch_recent_emails(user, since_time) do
    # Convert DateTime to Gmail query format
    query = "after:#{DateTime.to_unix(since_time)}"

    case Integrations.fetch_emails(user, query: query, limit: 10) do
      {:ok, emails} ->
        {:ok, emails}

      {:error, reason} ->
        Logger.warning("Failed to fetch recent emails for user #{user.id}: #{inspect(reason)}")
        {:ok, []}
    end
  end

  defp build_llm_messages(context) do
    prompt = build_orchestration_prompt(context)

    messages = [
      %{"role" => "system", "content" => get_system_prompt()},
      %{"role" => "user", "content" => prompt}
    ]

    {:ok, messages}
  end

  defp build_orchestration_prompt(context) do
    """
    Current time: #{DateTime.to_iso8601(context.current_time)}

    Active tasks (in progress):
    #{format_tasks_list(context.active_tasks)}

    Waiting tasks:
    #{format_tasks_list(context.waiting_tasks)}

    New emails received in last 15 minutes:
    #{format_emails_list(context.new_emails)}

    IMPORTANT: Review each task and determine its current state:

    1. For ACTIVE tasks - check if they are actually finished:
       - If the task objective has been met, use update_task_status to mark it as "completed"
       - If work is still needed, continue with the next step
       - If waiting for external response, change status to "waiting"

    2. For WAITING tasks - check if they can now proceed:
       - Review new emails to see if any are responses to waiting tasks
       - If a relevant response is found, resume the task and take appropriate action
       - If still waiting, leave status as "waiting"

    3. ALWAYS update task status when appropriate:
       - Use update_task_status with "completed" when task objectives are fully met
       - Use update_task_context to record what was accomplished
       - Don't leave completed tasks in "in_progress" status

    Remember: A task should be marked "completed" as soon as its description/objective is fulfilled.
    """
  end

  defp get_system_prompt do
    """
    You are a task orchestrator for a financial advisor's AI assistant. Your job is to manage and execute tasks that cannot be completed immediately.

    You have access to tools for:
    - update_task_status: Change task status (in_progress, waiting, completed, failed)
    - update_task_context: Add information about what was done
    - send_email: Send emails via Gmail
    - create_calendar_event: Create calendar events
    - search_gmail, search_contacts, search_calendar: Find information
    - All other available tools

    CRITICAL TASK COMPLETION RULES:
    1. ALWAYS mark tasks as "completed" when their objective is achieved
    2. If a task says "Email John about meeting" and you send the email, mark it COMPLETED
    3. If a task says "Schedule meeting with Sarah" and you create the calendar event, mark it COMPLETED
    4. Don't leave successfully executed tasks in "in_progress" status
    5. Update task context to record what was accomplished before marking complete

    Task Status Guidelines:
    - "in_progress": Task is actively being worked on
    - "waiting": Task is waiting for external response (email reply, etc.)
    - "completed": Task objective has been fully achieved
    - "failed": Task cannot be completed due to errors

    Be decisive about task completion - if the work is done, mark it done!
    """
  end

  # Debugging helpers

  defp inspect_context_summary(context) do
    %{
      active_tasks_count: length(context.active_tasks),
      waiting_tasks_count: length(context.waiting_tasks),
      new_emails_count: length(context.new_emails),
      current_time: context.current_time
    }
  end

  defp log_task_statuses_after_orchestration(user) do
    in_progress = TaskManagement.list_tasks_by_status(user.id, :in_progress)
    waiting = TaskManagement.list_tasks_by_status(user.id, :waiting)
    completed = TaskManagement.list_tasks_by_status(user.id, :completed)

    Logger.info("Post-orchestration task counts for user #{user.id}:")
    Logger.info("  In Progress: #{length(in_progress)}")
    Logger.info("  Waiting: #{length(waiting)}")
    Logger.info("  Completed: #{length(completed)}")

    # Log details of non-completed tasks
    Enum.each(in_progress ++ waiting, fn task ->
      Logger.info("  Task ##{task.id} (#{task.status}): #{task.description}")
    end)
  end

  # Formatting helpers

  defp format_tasks_for_llm(tasks) do
    Enum.map(tasks, fn task ->
      %{
        id: task.id,
        description: task.description,
        status: task.status,
        context: task.context,
        created_at: task.inserted_at,
        updated_at: task.updated_at
      }
    end)
  end

  defp format_emails_for_llm(emails) do
    Enum.map(emails, fn email ->
      %{
        id: email.id,
        from: email.from,
        to: email.to,
        subject: email.subject,
        body: String.slice(email.body || "", 0, 500),
        date: email.date
      }
    end)
  end

  defp format_tasks_list([]), do: "No tasks"

  defp format_tasks_list(tasks) do
    tasks
    |> Enum.map(fn task ->
      "- Task ##{task.id}: #{task.description} (#{task.status})"
    end)
    |> Enum.join("\n")
  end

  defp format_emails_list([]), do: "No new emails"

  defp format_emails_list(emails) do
    emails
    |> Enum.map(fn email ->
      "- From: #{email.from}, Subject: #{email.subject}"
    end)
    |> Enum.join("\n")
  end
end
