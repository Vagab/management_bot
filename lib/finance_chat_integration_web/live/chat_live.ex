defmodule FinanceChatIntegrationWeb.ChatLive do
  use FinanceChatIntegrationWeb, :live_view

  alias FinanceChatIntegration.{LLM, Chat, TaskManagement}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    messages = Chat.get_recent_messages(user.id, 20)

    tasks =
      TaskManagement.list_tasks_by_status(user.id, :in_progress) ++
        TaskManagement.list_tasks_by_status(user.id, :waiting)

    # Subscribe to PubSub for progress updates
    Phoenix.PubSub.subscribe(FinanceChatIntegration.PubSub, "chat:#{user.id}")

    {:ok,
     socket
     |> assign(:messages, messages)
     |> assign(:message_input, "")
     |> assign(:loading, false)
     |> assign(:progress_tool, nil)
     |> assign(:tasks, tasks)
     |> assign(:show_tasks, true)
     |> assign(:hubspot_connected, not is_nil(user.hubspot_access_token))}
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

  def handle_event("toggle_tasks", _, socket) do
    {:noreply, assign(socket, :show_tasks, !socket.assigns.show_tasks)}
  end

  def handle_info({:llm_response, _response}, socket) do
    user = socket.assigns.current_user
    # Refresh messages from database
    updated_messages = Chat.get_recent_messages(user.id, 20)
    # Refresh tasks as well (in case new tasks were created)
    updated_tasks =
      TaskManagement.list_tasks_by_status(user.id, :in_progress) ++
        TaskManagement.list_tasks_by_status(user.id, :waiting)

    socket =
      socket
      |> assign(:messages, updated_messages)
      |> assign(:tasks, updated_tasks)
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
    <div class="max-w-6xl mx-auto p-6">
      <!-- Mobile Tasks Toggle Button -->
      <div class="md:hidden fixed top-4 right-4 z-50">
        <button
          phx-click="toggle_tasks"
          class="bg-blue-500 text-white p-3 rounded-full shadow-lg hover:bg-blue-600"
          title="Toggle Tasks"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
            />
          </svg>
        </button>
      </div>

      <div class="flex gap-4 relative">
        <!-- Main Chat Area -->
        <div class="flex-1 bg-white rounded-xl shadow-lg border border-gray-200">
          <div class="border-b border-gray-200 p-6">
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-2xl font-bold text-gray-800">Chat with AI Assistant</h1>
                <p class="text-sm text-gray-500 mt-1">User: {@current_user.email}</p>
              </div>
              <%= unless @hubspot_connected do %>
                <div class="flex items-center gap-4">
                  <a
                    href="/hubspot/connect"
                    class="inline-flex items-center px-4 py-2 bg-orange-500 text-white text-sm font-medium rounded-lg hover:bg-orange-600 transition-colors"
                  >
                    <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
                    </svg>
                    Connect HubSpot
                  </a>
                </div>
              <% end %>
            </div>
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
        
    <!-- Tasks Panel -->
        <div class={"w-80 bg-white rounded-xl shadow-lg border border-gray-200 md:block #{if @show_tasks, do: "block", else: "hidden"} md:relative fixed md:top-0 top-0 right-0 h-full md:h-auto z-40"}>
          <div class="border-b border-gray-200 p-4">
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-semibold text-gray-800">Active Tasks</h2>
              <button
                phx-click="toggle_tasks"
                class="text-gray-500 hover:text-gray-700"
                title={if @show_tasks, do: "Collapse", else: "Expand"}
              >
                <%= if @show_tasks do %>
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M19 9l-7 7-7-7"
                    />
                  </svg>
                <% else %>
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 5l7 7-7 7"
                    />
                  </svg>
                <% end %>
              </button>
            </div>
            <p class="text-sm text-gray-500 mt-1">{length(@tasks)} active</p>
          </div>

          <div class="max-h-96 overflow-y-auto">
            <%= if Enum.empty?(@tasks) do %>
              <div class="p-4 text-center text-gray-500">
                <p class="text-sm">No active tasks</p>
              </div>
            <% else %>
              <div class="p-4 space-y-3">
                <%= for task <- @tasks do %>
                  <div class="p-3 bg-gray-50 rounded-lg border">
                    <div class="flex items-start justify-between">
                      <div class="flex-1">
                        <p class="text-sm font-medium text-gray-800 line-clamp-2">
                          {task.description}
                        </p>
                        <div class="flex items-center gap-2 mt-2">
                          <span class={"inline-flex items-center px-2 py-1 rounded-full text-xs font-medium #{task_status_style(task.status)}"}>
                            {String.capitalize(Atom.to_string(task.status))}
                          </span>
                          <span class="text-xs text-gray-500">
                            {format_task_time(task.inserted_at)}
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
        
    <!-- Mobile Overlay -->
        <%= if @show_tasks do %>
          <div class="md:hidden fixed inset-0 bg-black bg-opacity-50 z-30" phx-click="toggle_tasks">
          </div>
        <% end %>
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
  defp tool_progress_message("create_hubspot_note"), do: "Creating HubSpot note..."
  defp tool_progress_message("search_calendar"), do: "Checking calendar..."
  defp tool_progress_message("create_calendar_event"), do: "Creating calendar event..."
  defp tool_progress_message("search_data"), do: "Searching data..."
  defp tool_progress_message("create_task"), do: "Creating task..."
  defp tool_progress_message("update_task_status"), do: "Updating task status..."
  defp tool_progress_message("update_task_context"), do: "Updating task context..."
  defp tool_progress_message(_), do: "Working..."

  defp task_status_style(:in_progress), do: "bg-blue-100 text-blue-800"
  defp task_status_style(:waiting), do: "bg-yellow-100 text-yellow-800"
  defp task_status_style(:completed), do: "bg-green-100 text-green-800"
  defp task_status_style(:failed), do: "bg-red-100 text-red-800"
  defp task_status_style(_), do: "bg-gray-100 text-gray-800"

  defp format_task_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :minute)

    cond do
      diff < 1 -> "Just now"
      diff < 60 -> "#{diff}m ago"
      diff < 1440 -> "#{div(diff, 60)}h ago"
      true -> "#{div(diff, 1440)}d ago"
    end
  end
end
