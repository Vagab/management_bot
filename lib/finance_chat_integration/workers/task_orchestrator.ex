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
    LLM,
    Content.VectorSearch,
    Instructions
  }

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Starting task orchestration for all users")

    users = Accounts.list_users_with_tokens()

    Enum.each(users, fn user ->
      Logger.info("Processing tasks for user #{user.id}")

      # First sync recent emails and contacts to RAG system
      sync_recent_emails(user)
      sync_hubspot_contacts(user)

      # Process instructions against new events
      process_instructions(user)

      # Then orchestrate tasks
      orchestrate_tasks(user)
    end)

    Logger.info("Completed task orchestration for #{length(users)} users")
    :ok
  end

  defp sync_recent_emails(user) do
    Logger.info("Syncing recent emails for user #{user.id}")

    # Get emails from last 24 hours
    twenty_four_hours_ago = DateTime.utc_now() |> DateTime.add(-24, :hour)
    query = "after:#{DateTime.to_unix(twenty_four_hours_ago)}"

    case Integrations.fetch_emails(user, query: query, limit: 50) do
      {:ok, emails} ->
        Logger.info("Found #{length(emails)} recent emails for user #{user.id}")

        Enum.each(emails, fn email ->
          # Check if email already exists to avoid duplicates
          if not email_already_stored?(email, user.id) do
            # Create content chunk for each email
            content = format_email_for_rag(email)

            attrs = %{
              content: content,
              source: "gmail",
              user_id: user.id
            }

            case VectorSearch.create_chunk_with_embedding(attrs) do
              {:ok, _chunk} ->
                Logger.debug("Created content chunk for email: #{email.subject}")

              {:error, reason} ->
                Logger.warning(
                  "Failed to create content chunk for email #{email.subject}: #{inspect(reason)}"
                )
            end
          end
        end)

      {:error, reason} ->
        Logger.warning("Failed to fetch emails for user #{user.id}: #{inspect(reason)}")
    end
  end

  defp format_email_for_rag(email) do
    """
    Subject: #{email.subject}
    From: #{email.from}
    Date: #{email.date}

    #{email.body}
    """
  end

  defp email_already_stored?(email, user_id) do
    # Simple check - if content with same subject and from exists
    import Ecto.Query
    alias FinanceChatIntegration.{Content.ContentChunk, Repo}

    query =
      from c in ContentChunk,
        where: c.user_id == ^user_id,
        where: c.source == "gmail",
        where:
          fragment("? LIKE ?", c.content, ^"%Subject: #{email.subject}%From: #{email.from}%"),
        limit: 1

    Repo.exists?(query)
  end

  defp sync_hubspot_contacts(user) do
    Logger.info("Syncing HubSpot contacts for user #{user.id}")

    case Integrations.fetch_hubspot_contacts(user, limit: 100) do
      {:ok, contacts} ->
        Logger.info("Found #{length(contacts)} HubSpot contacts for user #{user.id}")

        Enum.each(contacts, fn contact ->
          # Check if contact already exists
          if not contact_already_stored?(contact, user.id) do
            content = format_contact_for_rag(contact)

            attrs = %{
              content: content,
              source: "hubspot",
              user_id: user.id
            }

            case VectorSearch.create_chunk_with_embedding(attrs) do
              {:ok, _chunk} ->
                Logger.debug("Created content chunk for contact: #{contact.email}")

              {:error, reason} ->
                Logger.warning(
                  "Failed to create content chunk for contact #{contact.email}: #{inspect(reason)}"
                )
            end
          end
        end)

      {:error, reason} ->
        Logger.warning("Failed to fetch HubSpot contacts for user #{user.id}: #{inspect(reason)}")
    end
  end

  defp format_contact_for_rag(contact) do
    """
    Contact: #{contact.first_name} #{contact.last_name}
    Email: #{contact.email}
    Company: #{contact.company}
    Phone: #{contact.phone}
    Job Title: #{contact.job_title}
    Lifecycle Stage: #{contact.lifecycle_stage}
    """
  end

  defp contact_already_stored?(contact, user_id) do
    # Simple check - if content with same email exists
    import Ecto.Query
    alias FinanceChatIntegration.{Content.ContentChunk, Repo}

    query =
      from c in ContentChunk,
        where: c.user_id == ^user_id,
        where: c.source == "hubspot",
        where: fragment("? LIKE ?", c.content, ^"%Email: #{contact.email}%"),
        limit: 1

    Repo.exists?(query)
  end

  @doc """
  Manual sync function for testing - can be called from IEx
  """
  def sync_user_data(user_id) do
    try do
      user = Accounts.get_user!(user_id)
      Logger.info("Manual sync started for user #{user.id}")
      sync_recent_emails(user)
      sync_hubspot_contacts(user)
      process_instructions(user)
      Logger.info("Manual sync completed for user #{user.id}")
      :ok
    rescue
      Ecto.NoResultsError ->
        {:error, :user_not_found}
    end
  end

  defp process_instructions(user) do
    Logger.info("Processing instructions for user #{user.id}")

    # Get user's active instructions
    instructions = Instructions.list_instructions(user.id)

    if length(instructions) > 0 do
      # Get recent events (emails from last hour)
      one_hour_ago = DateTime.utc_now() |> DateTime.add(-1, :hour)

      case fetch_recent_emails(user, one_hour_ago) do
        {:ok, recent_emails} when recent_emails != [] ->
          Logger.info(
            "Found #{length(recent_emails)} recent emails to evaluate against #{length(instructions)} instructions"
          )

          # Ask LLM to evaluate instructions against events
          evaluate_instructions_against_events(user, instructions, recent_emails)

        {:ok, []} ->
          Logger.debug("No recent emails found for instruction processing")
      end
    else
      Logger.debug("No instructions found for user #{user.id}")
    end
  end

  defp evaluate_instructions_against_events(user, instructions, recent_emails) do
    instructions_text = format_instructions_for_llm(instructions)
    events_text = format_events_for_llm(recent_emails)

    prompt = """
    You are evaluating user instructions against recent events to determine if any tasks should be created.

    User Instructions:
    #{instructions_text}

    Recent Events:
    #{events_text}

    For each instruction, determine if any of the recent events should trigger task creation. If so, create appropriate tasks using the create_task tool.

    Examples:
    - If instruction is "Follow up with new leads within 24 hours" and there's a new email from a potential client, create a follow-up task
    - If instruction is "Schedule meetings with clients who request them" and there's an email asking for a meeting, create a scheduling task
    - If instruction is "Send welcome emails to new contacts" and there's a new contact, create an email task

    Only create tasks if there's a clear match between an instruction and an event. Be selective and purposeful.
    """

    messages = [
      %{
        "role" => "system",
        "content" =>
          "You are a task orchestrator that evaluates instructions against events to create tasks automatically."
      },
      %{"role" => "user", "content" => prompt}
    ]

    case LLM.process_with_tools(messages, user, temperature: 0.3) do
      {:ok, _response} ->
        Logger.info("Instruction evaluation completed for user #{user.id}")

      {:error, reason} ->
        Logger.warning("Failed to evaluate instructions for user #{user.id}: #{inspect(reason)}")
    end
  end

  defp format_instructions_for_llm(instructions) do
    instructions
    |> Enum.with_index(1)
    |> Enum.map(fn {instruction, index} ->
      "#{index}. #{instruction.description}"
    end)
    |> Enum.join("\n")
  end

  defp format_events_for_llm(emails) do
    emails
    |> Enum.with_index(1)
    |> Enum.map(fn {email, index} ->
      "#{index}. EMAIL - From: #{email.from}, Subject: #{email.subject}, Date: #{email.date}"
    end)
    |> Enum.join("\n")
  end

  defp orchestrate_tasks(user) do
    with {:ok, context} <- collect_context(user),
         {:ok, messages} <- build_llm_messages(context) do
      Logger.info(
        "Starting LLM processing for user #{user.id} with context: #{inspect_context_summary(context)}"
      )

      # Log the actual prompt being sent to LLM
      user_message = Enum.find(messages, fn msg -> msg["role"] == "user" end)

      if user_message do
        Logger.info("=== ORCHESTRATION PROMPT ===")
        Logger.info(user_message["content"])
        Logger.info("=== END PROMPT ===")
      end

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
      active_tasks: active_tasks,
      waiting_tasks: waiting_tasks,
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

    CRITICAL TASK REVIEW PROCESS:

    FOR EACH TASK LISTED ABOVE, YOU MUST:

    1. READ the task description carefully
    2. CHECK if the task objective has already been completed based on:
       - The task description
       - Any context information provided
       - Recent emails that might indicate completion
    3. TAKE ACTION immediately:
       - If task is DONE: Use update_task_status to mark as "completed"
       - If task needs work: Execute the required actions using available tools
       - If waiting for response: Change status to "waiting"

    MANDATORY ACTIONS FOR EACH ACTIVE TASK:
    - If task says "Send email to X" → Send the email, then mark COMPLETED
    - If task says "Schedule meeting" → Create calendar event, then mark COMPLETED
    - If task says "Create contact" → Create the contact, then mark COMPLETED
    - If task says "Follow up" → Send follow-up email, then mark COMPLETED

    YOU MUST PROCESS EVERY SINGLE TASK LISTED. Do not ignore any tasks.

    COMPLETION CRITERIA: A task is complete when its stated objective is achieved. Be decisive!
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
      context_info =
        if task.context && map_size(task.context) > 0 do
          "\n  Context: #{inspect(task.context)}"
        else
          ""
        end

      time_info = format_task_time_elapsed(task.inserted_at)

      "- Task ##{task.id}: #{task.description}
  Status: #{task.status}
  Created: #{time_info}#{context_info}

  ACTION REQUIRED: Review if this task objective has been completed and update status accordingly."
    end)
    |> Enum.join("\n\n")
  end

  defp format_task_time_elapsed(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :minute)

    cond do
      diff < 60 -> "#{diff} minutes ago"
      diff < 1440 -> "#{div(diff, 60)} hours ago"
      true -> "#{div(diff, 1440)} days ago"
    end
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
