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

  @default_model "gpt-4o-mini"
  @max_context_chunks 3
  @max_conversation_history 10

  @doc """
  Main chat interface that handles user messages with RAG and tool calling.
  Now runs asynchronously and publishes results via PubSub.
  """
  def chat(message, user) do
    # Spawn async task for LLM processing
    Task.start(fn ->
      case chat_async(message, user) do
        {:ok, final_response} ->
          # Save conversation to database
          save_conversation(user, final_response)

          # Publish final result
          Phoenix.PubSub.broadcast(
            FinanceChatIntegration.PubSub,
            "chat:#{user.id}",
            {:llm_response, final_response}
          )

        {:error, reason} ->
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
         {:ok, response} <- call_llm_with_tools(messages),
         {:ok, final_response} <- process_llm_response(response, user) do
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

    If you need to perform actions like sending emails or scheduling meetings, use the appropriate tools. Always confirm important actions before executing them.
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

  defp user_message(content), do: %{"role" => "user", "content" => content}

  defp call_llm_with_tools(messages) do
    Integrations.chat_completion(messages,
      model: @default_model,
      tools: Tools.tool_definitions(),
      temperature: 0.7
    )
  end

  defp call_llm(messages) do
    Integrations.chat_completion(messages,
      model: @default_model,
      temperature: 0.7
    )
  end

  defp process_llm_response(response, user) do
    [choice | _] = response[:choices]
    message = choice["message"]

    cond do
      # LLM wants to call tools
      tool_calls = get_in(message, ["tool_calls"]) ->
        execute_tools_and_continue(tool_calls, message, user)

      # LLM provided a direct response
      content = get_in(message, ["content"]) ->
        {:ok, content}

      true ->
        {:error, "Invalid LLM response format"}
    end
  end

  defp execute_tools_and_continue(tool_calls, assistant_message, user) do
    # Execute all tool calls
    tool_results = execute_tool_calls(tool_calls, user)

    # Build messages for the next LLM call
    messages =
      [
        assistant_message,
        tool_results
      ]
      |> List.flatten()

    # Call LLM again with tool results
    case call_llm_with_tools(messages) do
      {:ok, response} ->
        # Get the final response content
        final_content = get_content_from_response(response)
        {:ok, final_content}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_tool_calls(tool_calls, user) do
    Enum.map(tool_calls, fn tool_call ->
      tool_id = tool_call["id"]
      function_name = get_in(tool_call, ["function", "name"])
      arguments_json = get_in(tool_call, ["function", "arguments"])

      # Broadcast progress update
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
            Jason.encode!(result)

          {:error, error} ->
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

  defp get_content_from_response(response) do
    get_in(response, [:choices, Access.at(0), "message", "content"]) ||
      "I apologize, but I couldn't generate a proper response."
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
