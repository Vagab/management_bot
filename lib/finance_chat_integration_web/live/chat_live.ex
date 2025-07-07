defmodule FinanceChatIntegrationWeb.ChatLive do
  use FinanceChatIntegrationWeb, :live_view

  alias FinanceChatIntegration.{LLM, Chat}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    messages = Chat.get_recent_messages(user.id, 20)

    # Subscribe to PubSub for progress updates
    Phoenix.PubSub.subscribe(FinanceChatIntegration.PubSub, "chat:#{user.id}")

    {:ok,
     socket
     |> assign(:messages, messages)
     |> assign(:message_input, "")
     |> assign(:loading, false)
     |> assign(:progress_tool, nil)}
  end

  def handle_event("send_message", %{"message" => message}, socket) do
    if String.trim(message) != "" do
      user = socket.assigns.current_user

      # Save user message to database immediately
      case Chat.create_chat_message(%{
             user_id: user.id,
             role: :user,
             content: message
           }) do
        {:ok, _} ->
          # Get updated messages from database
          updated_messages = Chat.get_recent_messages(user.id, 20)

          socket =
            socket
            |> assign(:messages, updated_messages)
            |> assign(:loading, true)
            |> assign(:message_input, "")
            |> assign(:progress_tool, nil)

          # Start async LLM processing
          LLM.chat(message, user)

          {:noreply, socket}

        {:error, _} ->
          socket =
            socket
            |> put_flash(:error, "Failed to save message")

          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :message_input, message)}
  end

  def handle_event("delete_message", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case Chat.delete_chat_message(id, user.id) do
      {:ok, _} ->
        updated_messages = Chat.get_recent_messages(user.id, 20)

        socket =
          socket
          |> assign(:messages, updated_messages)
          |> put_flash(:info, "Message deleted")

        {:noreply, socket}

      {:error, _} ->
        socket =
          socket
          |> put_flash(:error, "Failed to delete message")

        {:noreply, socket}
    end
  end

  def handle_info({:llm_response, _response}, socket) do
    user = socket.assigns.current_user
    # Refresh messages from database
    updated_messages = Chat.get_recent_messages(user.id, 20)

    socket =
      socket
      |> assign(:messages, updated_messages)
      |> assign(:loading, false)
      |> assign(:progress_tool, nil)

    {:noreply, socket}
  end

  def handle_info({:llm_error, reason}, socket) do
    socket =
      socket
      |> assign(:loading, false)
      |> assign(:progress_tool, nil)
      |> put_flash(:error, "Error: #{inspect(reason)}")

    {:noreply, socket}
  end

  def handle_info({:llm_tool_executing, tool_name}, socket) do
    {:noreply, assign(socket, :progress_tool, tool_name)}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6">
      <div class="bg-white rounded-xl shadow-lg border border-gray-200">
        <div class="border-b border-gray-200 p-6">
          <h1 class="text-2xl font-bold text-gray-800">Chat with AI Assistant</h1>
          <p class="text-sm text-gray-500 mt-1">User: {@current_user.email}</p>
        </div>

        <div
          class="h-96 overflow-y-auto p-6 space-y-4"
          id="messages-container"
          phx-hook="ScrollToBottom"
        >
          <%= for message <- @messages do %>
            <div class={"flex #{if message.role == :user, do: "justify-end", else: "justify-start"} mb-4"}>
              <div class={"relative group max-w-[70%] px-4 py-3 rounded-2xl #{message_style(message.role)}"}>
                <div class="text-xs opacity-75 mb-1 font-medium">
                  {if message.role == :user, do: "You", else: "Assistant"}
                </div>
                <div class="text-sm whitespace-pre-wrap leading-relaxed">{message.content}</div>
                <%= if message.role == :user and message.id do %>
                  <button
                    phx-click="delete_message"
                    phx-value-id={message.id}
                    class="absolute -top-2 -right-2 w-6 h-6 bg-red-500 hover:bg-red-600 text-white rounded-full text-xs opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center"
                    title="Delete message"
                  >
                    ×
                  </button>
                <% end %>
              </div>
            </div>
          <% end %>

          <%= if @loading do %>
            <div class="flex justify-start mb-4">
              <div class="max-w-[70%] px-4 py-3 rounded-2xl bg-gray-100 border border-gray-200">
                <div class="text-xs text-gray-500 mb-1 font-medium">Assistant</div>
                <div class="text-sm text-gray-600 flex items-center">
                  <div class="animate-pulse flex space-x-1">
                    <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div>
                    <div
                      class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"
                      style="animation-delay: 0.1s"
                    >
                    </div>
                    <div
                      class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"
                      style="animation-delay: 0.2s"
                    >
                    </div>
                  </div>
                  <span class="ml-2">{tool_progress_message(@progress_tool)}</span>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <div class="border-t border-gray-200 p-6">
          <form phx-submit="send_message" class="flex gap-3">
            <input
              type="text"
              name="message"
              value={@message_input}
              phx-change="update_message"
              placeholder="Type your message..."
              class="flex-1 border border-gray-300 rounded-xl px-4 py-3 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              disabled={@loading}
            />
            <button
              type="submit"
              class="px-6 py-3 bg-blue-500 text-white rounded-xl hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed font-medium transition-colors"
              disabled={@loading or String.trim(@message_input) == ""}
            >
              Send
            </button>
          </form>
        </div>
      </div>

      <div class="mt-6 p-4 bg-gray-50 rounded-lg">
        <p class="text-sm font-medium text-gray-700 mb-2">Try asking:</p>
        <ul class="text-sm text-gray-600 space-y-1">
          <li>• "Who mentioned baseball?"</li>
          <li>• "Search for emails about AAPL"</li>
          <li>• "What meetings do I have this week?"</li>
        </ul>
      </div>
    </div>
    """
  end

  defp message_style(:user), do: "bg-blue-500 text-white shadow-md"
  defp message_style(:assistant), do: "bg-gray-100 text-gray-900 border border-gray-200 shadow-sm"

  defp tool_progress_message(nil), do: "Thinking..."
  defp tool_progress_message("search_gmail"), do: "Looking through emails..."
  defp tool_progress_message("get_email_details"), do: "Reading email details..."
  defp tool_progress_message("send_email"), do: "Sending an email..."
  defp tool_progress_message("search_contacts"), do: "Searching contacts..."
  defp tool_progress_message("get_contact_details"), do: "Getting contact details..."
  defp tool_progress_message("create_hubspot_contact"), do: "Creating contact..."
  defp tool_progress_message("update_hubspot_contact"), do: "Updating contact..."
  defp tool_progress_message("search_calendar"), do: "Checking calendar..."
  defp tool_progress_message("create_calendar_event"), do: "Creating calendar event..."
  defp tool_progress_message("search_data"), do: "Searching data..."
  defp tool_progress_message(_), do: "Working..."
end
