defmodule FinanceChatIntegration.LLM do
  @moduledoc """
  LLM interface with RAG and tool calling integration.

  This module provides:
  - Chat completion with automatic RAG context
  - Tool calling integration
  - Conversation management
  - Error handling and fallbacks
  """

  alias FinanceChatIntegration.{Integrations, Tools, Content.VectorSearch, Chat}
  require Logger

  @default_model "gpt-4o-mini"
  @max_context_chunks 3
  @max_conversation_history 10
  @max_tool_iterations 10

  @doc """
  Main chat interface that handles user messages with RAG and tool calling.
  Now runs asynchronously and publishes results via PubSub.
  """
  def chat(message, user) do
    # Spawn async task for LLM processing
    Task.start(fn ->
      Logger.info("Starting LLM chat processing for user #{user.id}")

      case chat_async(message, user) do
        {:ok, final_response} ->
          Logger.info("LLM chat completed successfully for user #{user.id}")

          # Save conversation to database
          save_conversation(user, final_response)

          # Publish final result
          Phoenix.PubSub.broadcast(
            FinanceChatIntegration.PubSub,
            "chat:#{user.id}",
            {:llm_response, final_response}
          )

        {:error, reason} ->
          Logger.error("LLM chat failed for user #{user.id}: #{inspect(reason)}")

          # Publish error
          Phoenix.PubSub.broadcast(
            FinanceChatIntegration.PubSub,
            "chat:#{user.id}",
            {:llm_error, reason}
          )
      end
    end)

    {:ok, :async}
  end

  # Synchronous version of chat for internal use.
  defp chat_async(message, user) do
    with {:ok, messages} <- build_conversation_context(message, user),
         {:ok, final_response} <- process_llm_with_tools(messages, user, 0) do
      {:ok, final_response}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Private Functions

  defp build_conversation_context(message, user) do
    # 1. Get recent conversation history
    recent_messages = Chat.get_recent_messages(user.id, @max_conversation_history)

    # 2. Get RAG context for the current message
    rag_context = get_rag_context(message, user.id)

    # 3. Build message array for OpenAI
    messages =
      [
        system_message_with_context(rag_context),
        conversation_history_to_messages(recent_messages)
      ]
      |> List.flatten()

    {:ok, messages}
  end

  defp get_rag_context(message, user_id) do
    case VectorSearch.search_for_context(message, user_id, limit: @max_context_chunks) do
      {:ok, results} -> results
      {:error, _} -> []
    end
  end

  defp system_message_with_context(rag_context) do
    context_text = format_rag_context(rag_context)

    content = """
    You are a helpful AI assistant for a financial advisor. You have access to the user's emails, contacts, and calendar data.

    #{if context_text != "", do: "Relevant context from user's data:\n#{context_text}\n", else: ""}

    You can use the available tools to search for more information, send emails, schedule meetings, and manage contacts. Always be helpful, professional, and accurate. When referencing information from the user's data, mention the source (email, contact, calendar).

    IMPORTANT: For workflows that cannot be completed immediately, you MUST create a task using the create_task tool. Examples of when to create tasks:
    - "Send email and schedule meeting when they respond" - CREATE TASK (requires waiting for response)
    - "Email someone and wait for their availability" - CREATE TASK (requires waiting for availability confirmation)
    - "Follow up in 3 days" - CREATE TASK (requires waiting for time to pass)
    - "Send welcome email to new leads" - CREATE TASK (ongoing instruction)

    If your workflow has "and then" steps that depend on external responses or future timing, use create_task FIRST, then execute the immediate actions.

    Always confirm important actions before executing them.
    """

    %{"role" => "system", "content" => content}
  end

  defp format_rag_context([]), do: ""

  defp format_rag_context(results) do
    results
    |> Enum.with_index(1)
    |> Enum.map(fn {result, index} ->
      "#{index}. [#{result.source}] #{result.content} (similarity: #{result.similarity})"
    end)
    |> Enum.join("\n")
  end

  defp conversation_history_to_messages(chat_messages) do
    Enum.map(chat_messages, fn msg ->
      %{
        "role" => Atom.to_string(msg.role),
        "content" => msg.content
      }
    end)
  end

  defp call_llm_with_tools(messages) do
    Integrations.chat_completion(messages,
      model: @default_model,
      tools: Tools.tool_definitions(),
      temperature: 0.7
    )
  end

  # New recursive function that handles tool calling with limits
  defp process_llm_with_tools(_messages, user, iteration)
       when iteration >= @max_tool_iterations do
    Logger.warning(
      "Maximum tool iterations (#{@max_tool_iterations}) reached for user #{user.id}"
    )

    {:error, "Maximum tool calling iterations reached"}
  end

  defp process_llm_with_tools(messages, user, iteration) do
    Logger.info("LLM iteration #{iteration} for user #{user.id}")

    case call_llm_with_tools(messages) do
      {:ok, response} ->
        process_llm_response(response, messages, user, iteration)

      {:error, reason} ->
        Logger.error("LLM call failed at iteration #{iteration}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_llm_response(response, conversation_messages, user, iteration) do
    [choice | _] = response[:choices]
    message = choice["message"]

    cond do
      # LLM wants to call tools
      tool_calls = get_in(message, ["tool_calls"]) ->
        Logger.info("LLM requesting #{length(tool_calls)} tool calls at iteration #{iteration}")
        execute_tools_and_continue(tool_calls, message, conversation_messages, user, iteration)

      # LLM provided a direct response
      content = get_in(message, ["content"]) ->
        Logger.info("LLM provided final response at iteration #{iteration}")
        {:ok, content}

      true ->
        Logger.error("Invalid LLM response format at iteration #{iteration}")
        {:error, "Invalid LLM response format"}
    end
  end

  defp execute_tools_and_continue(
         tool_calls,
         assistant_message,
         conversation_messages,
         user,
         iteration
       ) do
    # Execute all tool calls
    tool_results = execute_tool_calls(tool_calls, user)

    # Build messages for the next LLM call - KEEP FULL CONVERSATION CONTEXT
    updated_messages =
      conversation_messages ++
        [assistant_message | tool_results]

    # Recursively call LLM with updated conversation context
    process_llm_with_tools(updated_messages, user, iteration + 1)
  end

  defp execute_tool_calls(tool_calls, user) do
    Enum.map(tool_calls, fn tool_call ->
      tool_id = tool_call["id"]
      function_name = get_in(tool_call, ["function", "name"])
      arguments_json = get_in(tool_call, ["function", "arguments"])

      # Log and broadcast progress update
      Logger.info("Executing tool: #{function_name} for user #{user.id}")

      Phoenix.PubSub.broadcast(
        FinanceChatIntegration.PubSub,
        "chat:#{user.id}",
        {:llm_tool_executing, function_name}
      )

      # Parse arguments
      arguments =
        case Jason.decode(arguments_json) do
          {:ok, args} -> args
          {:error, _} -> %{}
        end

      # Execute the tool
      result =
        case Tools.execute_tool(function_name, arguments, user) do
          {:ok, result} ->
            Logger.info("Tool #{function_name} executed successfully for user #{user.id}")
            Jason.encode!(result)

          {:error, error} ->
            Logger.error("Tool #{function_name} failed for user #{user.id}: #{inspect(error)}")
            Jason.encode!(%{"error" => error})
        end

      # Format as tool result message for OpenAI
      %{
        "role" => "tool",
        "tool_call_id" => tool_id,
        "content" => result
      }
    end)
  end

  defp save_conversation(user, assistant_response) do
    # Save assistant response
    Chat.create_chat_message(%{
      user_id: user.id,
      role: :assistant,
      content: assistant_response
    })
  end

  @doc """
  Generate embeddings for content (used by background jobs).
  """
  def generate_embedding(text) do
    case Integrations.create_embedding(text) do
      {:ok, embedding} -> {:ok, embedding}
      {:error, reason} -> {:error, reason}
    end
  end
end
