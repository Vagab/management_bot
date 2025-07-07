defmodule FinanceChatIntegrationWeb.ChatLive do
  use FinanceChatIntegrationWeb, :live_view

  alias FinanceChatIntegration.{LLM, Chat}
  alias FinanceChatIntegration.Chat.ChatMessage

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    messages = Chat.get_recent_messages(user.id, 20)

    {:ok,
     socket
     |> assign(:messages, messages)
     |> assign(:message_input, "")
     |> assign(:loading, false)}
  end

  def mount(_params, _session, socket) do
    {:ok, redirect(socket, to: "/users/log_in")}
  end

  def handle_event("send_message", %{"message" => message}, socket) do
    if String.trim(message) != "" do
      user = socket.assigns.current_user

      # Start loading state
      socket =
        socket
        |> assign(
          :messages,
          socket.assigns.messages ++ [%ChatMessage{role: :user, content: message}]
        )
        |> assign(:loading, true)
        |> assign(:message_input, "")

      # Send async message to handle LLM call
      send(self(), {:process_message, message, user})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :message_input, message)}
  end

  def handle_info({:process_message, message, user}, socket) do
    # Call LLM in the background
    case LLM.chat(message, user) do
      {:ok, _response} ->
        # Refresh messages from database
        updated_messages = Chat.get_recent_messages(user.id, 20)

        socket =
          socket
          |> assign(:messages, updated_messages)
          |> assign(:loading, false)

        {:noreply, socket}

      {:error, reason} ->
        # Handle error - could add error flash here
        socket =
          socket
          |> assign(:loading, false)
          |> put_flash(:error, "Error: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-4">
      <div class="border rounded-lg bg-white shadow-sm">
        <div class="border-b p-4">
          <h1 class="text-xl font-semibold">Chat with AI Assistant</h1>
          <p class="text-sm text-gray-600">User: {@current_user.email}</p>
        </div>

        <div class="h-96 overflow-y-auto p-4 space-y-4" id="messages-container" phx-update="ignore">
          <%= for message <- @messages do %>
            <div class={"flex #{if message.role == :user, do: "justify-end", else: "justify-start"}"}>
              <div class={"max-w-xs lg:max-w-md px-4 py-2 rounded-lg #{message_style(message.role)}"}>
                <div class="text-xs text-gray-500 mb-1">
                  {if message.role == :user, do: "You", else: "Assistant"}
                </div>
                <div class="text-sm whitespace-pre-wrap">{message.content}</div>
              </div>
            </div>
          <% end %>

          <%= if @loading do %>
            <div class="flex justify-start">
              <div class="max-w-xs lg:max-w-md px-4 py-2 rounded-lg bg-gray-100">
                <div class="text-xs text-gray-500 mb-1">Assistant</div>
                <div class="text-sm">Thinking...</div>
              </div>
            </div>
          <% end %>
        </div>

        <div class="border-t p-4">
          <form phx-submit="send_message" class="flex gap-2">
            <input
              type="text"
              name="message"
              value={@message_input}
              phx-change="update_message"
              placeholder="Type your message..."
              class="flex-1 border rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
              disabled={@loading}
            />
            <button
              type="submit"
              class="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 disabled:opacity-50"
              disabled={@loading or String.trim(@message_input) == ""}
            >
              Send
            </button>
          </form>
        </div>
      </div>

      <div class="mt-4 text-xs text-gray-500">
        <p>Try asking:</p>
        <ul class="list-disc list-inside mt-1">
          <li>"Who mentioned baseball?"</li>
          <li>"Search for emails about AAPL"</li>
          <li>"What meetings do I have this week?"</li>
        </ul>
      </div>
    </div>
    """
  end

  defp message_style(:user), do: "bg-blue-500 text-white"
  defp message_style(:assistant), do: "bg-gray-100 text-gray-900"
end
