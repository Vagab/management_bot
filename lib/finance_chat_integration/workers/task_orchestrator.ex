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
    Tools,
    Accounts
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
         {:ok, llm_response} <- ask_llm_for_actions(context, user),
         :ok <- execute_llm_actions(llm_response, user) do
      Logger.info("Task orchestration completed for user #{user.id}")
      :ok
    else
      {:error, reason} ->
        Logger.error("Task orchestration failed for user #{user.id}: #{inspect(reason)}")
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

  defp ask_llm_for_actions(context, user) do
    Logger.info("Asking LLM for task actions for user #{user.id}")

    prompt = build_orchestration_prompt(context)

    messages = [
      %{"role" => "system", "content" => get_system_prompt()},
      %{"role" => "user", "content" => prompt}
    ]

    case Integrations.chat_completion(messages,
           model: "gpt-4o-mini",
           tools: get_task_management_tools(),
           temperature: 0.3
         ) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_orchestration_prompt(context) do
    """
    Current time: #{DateTime.to_iso8601(context.current_time)}

    Active tasks (in progress):
    #{format_tasks_list(context.active_tasks)}

    Waiting tasks:
    #{format_tasks_list(context.waiting_tasks)}

    New emails received in last 5 minutes:
    #{format_emails_list(context.new_emails)}

    Review all tasks and recent activity. Determine what actions to take:
    1. Are any waiting tasks ready to resume based on new emails?
    2. Are any active tasks ready for the next step?
    3. Should any tasks be completed or updated?

    Use the available tools to take appropriate actions.
    """
  end

  defp get_system_prompt do
    """
    You are a task orchestrator for a financial advisor's AI assistant. Your job is to manage and execute tasks that cannot be completed immediately.

    You have access to tools for:
    - Updating task status and context
    - Completing tasks
    - Sending emails
    - Creating calendar events
    - Searching for information

    Guidelines:
    1. Only take action if there's a clear reason to do so
    2. Update task context with your reasoning
    3. Complete tasks when their objectives are met
    4. Move tasks to 'waiting' status when waiting for external responses
    5. Be conservative - don't take actions unless you're confident
    """
  end

  defp get_task_management_tools do
    # Use all tools from Tools module (includes task management tools)
    Tools.tool_definitions()
  end

  defp execute_llm_actions(response, user) do
    Logger.info("Executing LLM actions for user #{user.id}")

    [choice | _] = response[:choices]
    message = choice["message"]

    case get_in(message, ["tool_calls"]) do
      nil ->
        Logger.info("No tool calls requested by LLM for user #{user.id}")
        :ok

      tool_calls ->
        Logger.info("Executing #{length(tool_calls)} tool calls for user #{user.id}")

        Enum.each(tool_calls, fn tool_call ->
          execute_tool_call(tool_call, user)
        end)

        :ok
    end
  end

  defp execute_tool_call(tool_call, user) do
    function_name = get_in(tool_call, ["function", "name"])
    arguments_json = get_in(tool_call, ["function", "arguments"])

    arguments =
      case Jason.decode(arguments_json) do
        {:ok, args} -> args
        {:error, _} -> %{}
      end

    Logger.info("Executing tool: #{function_name} for user #{user.id}")

    # Execute all tools through the Tools module
    case Tools.execute_tool(function_name, arguments, user) do
      {:ok, _result} ->
        Logger.info("Tool #{function_name} executed successfully")

      {:error, error} ->
        Logger.error("Tool #{function_name} failed: #{inspect(error)}")
    end
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
