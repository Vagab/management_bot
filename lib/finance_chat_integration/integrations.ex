defmodule FinanceChatIntegration.Integrations do
  @moduledoc """
  Main integration module that coordinates all API clients.

  This module provides a unified interface for interacting with
  Gmail, Google Calendar, HubSpot, and OpenAI APIs using direct HTTP calls.
  """

  alias FinanceChatIntegration.Integrations.HubspotClient

  # Gmail operations using direct HTTP calls

  @doc """
  Fetches emails for a user using their Google OAuth token.
  """
  def fetch_emails(user, opts \\ []) do
    case get_google_access_token(user) do
      {:ok, token} ->
        query = opts[:query] || ""

        url = "https://gmail.googleapis.com/gmail/v1/users/me/messages"
        headers = [{"Authorization", "Bearer #{token}"}]
        params = [{"q", query}, {"maxResults", "100"}]

        case Req.get(url, headers: headers, params: params) do
          {:ok, %{status: 200, body: response}} ->
            messages = response["messages"] || []
            fetch_message_details(token, messages)

          {:ok, %{status: status, body: error}} ->
            {:error, %{status: status, error: error}}

          {:error, reason} ->
            {:error, reason}
        end

      error ->
        error
    end
  end

  @doc """
  Sends an email via Gmail API.
  """
  def send_email(user, %{to: to, subject: subject, body: body}) do
    case get_google_access_token(user) do
      {:ok, token} ->
        message = create_email_message(to, subject, body)

        url = "https://gmail.googleapis.com/gmail/v1/users/me/messages/send"

        headers = [
          {"Authorization", "Bearer #{token}"},
          {"Content-Type", "application/json"}
        ]

        body_json = %{raw: message}

        case Req.post(url, headers: headers, json: body_json) do
          {:ok, %{status: 200, body: response}} ->
            {:ok, response}

          {:ok, %{status: status, body: error}} ->
            {:error, %{status: status, error: error}}

          {:error, reason} ->
            {:error, reason}
        end

      error ->
        error
    end
  end

  # Calendar operations using direct HTTP calls

  @doc """
  Fetches calendar events for a user.
  """
  def fetch_calendar_events(user, opts \\ []) do
    case get_google_access_token(user) do
      {:ok, token} ->
        calendar_id = opts[:calendar_id] || "primary"

        url = "https://www.googleapis.com/calendar/v3/calendars/#{calendar_id}/events"
        headers = [{"Authorization", "Bearer #{token}"}]

        params = [
          {"maxResults", "100"},
          {"singleEvents", "true"},
          {"orderBy", "startTime"}
        ]

        params = if opts[:time_min], do: [{"timeMin", opts[:time_min]} | params], else: params
        params = if opts[:time_max], do: [{"timeMax", opts[:time_max]} | params], else: params

        case Req.get(url, headers: headers, params: params) do
          {:ok, %{status: 200, body: response}} ->
            events = response["items"] || []
            parsed_events = Enum.map(events, &parse_calendar_event/1)
            {:ok, parsed_events}

          {:ok, %{status: status, body: error}} ->
            {:error, %{status: status, error: error}}

          {:error, reason} ->
            {:error, reason}
        end

      error ->
        error
    end
  end

  @doc """
  Creates a new calendar event.
  """
  def create_calendar_event(user, event_params, opts \\ []) do
    case get_google_access_token(user) do
      {:ok, token} ->
        calendar_id = opts[:calendar_id] || "primary"

        url = "https://www.googleapis.com/calendar/v3/calendars/#{calendar_id}/events"

        headers = [
          {"Authorization", "Bearer #{token}"},
          {"Content-Type", "application/json"}
        ]

        event_body = build_calendar_event(event_params)

        case Req.post(url, headers: headers, json: event_body) do
          {:ok, %{status: 200, body: response}} ->
            {:ok, parse_calendar_event(response)}

          {:ok, %{status: status, body: error}} ->
            {:error, %{status: status, error: error}}

          {:error, reason} ->
            {:error, reason}
        end

      error ->
        error
    end
  end

  @doc """
  Finds available time slots in a user's calendar.
  """
  def find_available_slots(user, date, duration_minutes \\ 60, _opts \\ []) do
    start_time = DateTime.new!(date, ~T[09:00:00], "Etc/UTC")
    end_time = DateTime.new!(date, ~T[17:00:00], "Etc/UTC")

    time_min = DateTime.to_iso8601(start_time)
    time_max = DateTime.to_iso8601(end_time)

    case fetch_calendar_events(user, time_min: time_min, time_max: time_max) do
      {:ok, events} ->
        busy_times = extract_busy_times(events)

        available_slots =
          calculate_available_slots(start_time, end_time, busy_times, duration_minutes)

        {:ok, available_slots}

      error ->
        error
    end
  end

  # HubSpot operations using custom client

  @doc """
  Fetches HubSpot contacts for a user.
  """
  def fetch_hubspot_contacts(user, opts \\ []) do
    case get_hubspot_access_token(user) do
      {:ok, token} ->
        HubspotClient.fetch_contacts(token, opts)

      error ->
        error
    end
  end

  @doc """
  Searches for HubSpot contacts by email.
  """
  def search_hubspot_contacts_by_email(user, email) do
    case get_hubspot_access_token(user) do
      {:ok, token} ->
        HubspotClient.search_contacts_by_email(token, email)

      error ->
        error
    end
  end

  @doc """
  Creates a new HubSpot contact.
  """
  def create_hubspot_contact(user, contact_params) do
    case get_hubspot_access_token(user) do
      {:ok, token} ->
        HubspotClient.create_contact(token, contact_params)

      error ->
        error
    end
  end

  @doc """
  Creates a note for a HubSpot contact.
  """
  def create_hubspot_contact_note(user, contact_id, note_body) do
    case get_hubspot_access_token(user) do
      {:ok, token} ->
        HubspotClient.create_contact_note(token, contact_id, note_body)

      error ->
        error
    end
  end

  # OpenAI operations using openai library

  @doc """
  Generates a chat completion using OpenAI.
  """
  def chat_completion(messages, opts \\ []) do
    model = opts[:model] || "gpt-3.5-turbo"

    params = [
      model: model,
      messages: messages,
      temperature: opts[:temperature] || 0.7,
      max_tokens: opts[:max_tokens] || 1500
    ]

    params = if opts[:tools], do: Keyword.put(params, :tools, opts[:tools]), else: params

    IO.inspect("sending open ai request with #{inspect(params)}")

    case OpenAI.chat_completion(params) do
      {:ok, response} -> {:ok, response} |> IO.inspect(label: "AI response")
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Creates an embedding for the given text.
  """
  def create_embedding(text, opts \\ []) do
    model = opts[:model] || "text-embedding-3-small"

    params = [
      model: model,
      input: text
    ]

    case OpenAI.embeddings(params) do
      {:ok, %{data: [%{embedding: embedding} | _]}} -> {:ok, embedding}
      {:ok, _} -> {:error, "No embedding data returned"}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Creates embeddings for multiple texts.
  """
  def create_embeddings(texts, opts \\ []) when is_list(texts) do
    model = opts[:model] || "text-embedding-3-small"

    params = [
      model: model,
      input: texts
    ]

    case OpenAI.embeddings(params) do
      {:ok, %{data: data}} ->
        embeddings = Enum.map(data, & &1.embedding)
        {:ok, embeddings}

      {:error, error} ->
        {:error, error}
    end
  end

  # Helper functions

  defp get_google_access_token(user) do
    case user.google_access_token do
      nil ->
        {:error, :no_google_token}

      token ->
        if token_expired?(user.google_token_expires_at) do
          case refresh_google_token(user) do
            {:ok, new_token} -> {:ok, new_token}
            error -> error
          end
        else
          {:ok, token}
        end
    end
  end

  defp get_hubspot_access_token(user) do
    case user.hubspot_access_token do
      nil ->
        {:error, :no_hubspot_token}

      token ->
        if token_expired?(user.hubspot_token_expires_at) do
          case refresh_hubspot_token(user) do
            {:ok, new_token} -> {:ok, new_token}
            error -> error
          end
        else
          {:ok, token}
        end
    end
  end

  defp token_expired?(nil), do: true

  defp token_expired?(expires_at) do
    NaiveDateTime.compare(expires_at, NaiveDateTime.utc_now()) == :lt
  end

  def refresh_hubspot_token(user) do
    if user.hubspot_refresh_token do
      config = Application.fetch_env!(:oauth2, :hubspot_provider)

      params = %{
        grant_type: "refresh_token",
        refresh_token: user.hubspot_refresh_token,
        client_id: config[:client_id],
        client_secret: config[:client_secret]
      }

      case Req.post(config[:token_url], form: params) do
        {:ok, %{status: 200, body: response}} ->
          # Update the user's tokens
          expires_at =
            if response["expires_in"] do
              DateTime.utc_now()
              |> DateTime.add(response["expires_in"], :second)
              |> DateTime.to_naive()
            else
              nil
            end

          token_params = %{
            hubspot_access_token: response["access_token"],
            hubspot_token_expires_at: expires_at
          }

          # Update the user with new tokens
          alias FinanceChatIntegration.Accounts

          case Accounts.get_user!(user.id)
               |> Accounts.User.hubspot_changeset(token_params)
               |> FinanceChatIntegration.Repo.update() do
            {:ok, _updated_user} -> {:ok, response["access_token"]}
            error -> error
          end

        {:ok, %{status: status, body: error}} ->
          {:error, %{status: status, error: error}}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :no_refresh_token}
    end
  end

  defp refresh_google_token(user) do
    if user.google_refresh_token do
      config = %{
        client_id: Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_id],
        client_secret:
          Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_secret],
        token_url: "https://oauth2.googleapis.com/token"
      }

      params = %{
        grant_type: "refresh_token",
        refresh_token: user.google_refresh_token,
        client_id: config.client_id,
        client_secret: config.client_secret
      }

      case Req.post(config.token_url, form: params) do
        {:ok, %{status: 200, body: response}} ->
          # Update the user's tokens
          expires_at =
            if response["expires_in"] do
              DateTime.utc_now()
              |> DateTime.add(response["expires_in"], :second)
              |> DateTime.to_naive()
            else
              nil
            end

          token_params = %{
            google_access_token: response["access_token"],
            google_token_expires_at: expires_at
          }

          # Update the user with new tokens
          alias FinanceChatIntegration.Accounts

          case Accounts.get_user!(user.id)
               |> Accounts.User.google_changeset(token_params)
               |> FinanceChatIntegration.Repo.update() do
            {:ok, _updated_user} -> {:ok, response["access_token"]}
            error -> error
          end

        {:ok, %{status: status, body: error}} ->
          {:error, %{status: status, error: error}}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :no_refresh_token}
    end
  end

  defp fetch_message_details(token, messages) do
    detailed_messages =
      messages
      |> Enum.map(fn message ->
        url = "https://gmail.googleapis.com/gmail/v1/users/me/messages/#{message["id"]}"
        headers = [{"Authorization", "Bearer #{token}"}]
        params = [{"format", "full"}]

        case Req.get(url, headers: headers, params: params) do
          {:ok, %{status: 200, body: response}} ->
            parse_email_message(response)

          {:error, _} ->
            nil
        end
      end)
      |> Enum.filter(& &1)

    {:ok, detailed_messages}
  end

  defp parse_email_message(message) do
    headers = get_in(message, ["payload", "headers"]) || []

    %{
      id: message["id"],
      thread_id: message["threadId"],
      subject: get_header_value(headers, "Subject"),
      from: get_header_value(headers, "From"),
      to: get_header_value(headers, "To"),
      date: get_header_value(headers, "Date"),
      body: extract_email_body(message["payload"]),
      snippet: message["snippet"]
    }
  end

  defp get_header_value(headers, name) do
    case Enum.find(headers, fn header -> header["name"] == name end) do
      %{"value" => value} -> value
      _ -> ""
    end
  end

  defp extract_email_body(payload) do
    cond do
      payload["body"] && payload["body"]["data"] ->
        decode_base64_url(payload["body"]["data"])

      payload["parts"] ->
        payload["parts"]
        |> Enum.find(fn part -> part["mimeType"] in ["text/plain", "text/html"] end)
        |> case do
          %{"body" => %{"data" => data}} -> decode_base64_url(data)
          _ -> ""
        end

      true ->
        ""
    end
  end

  defp decode_base64_url(data) do
    data
    |> String.replace("-", "+")
    |> String.replace("_", "/")
    |> Base.decode64!(padding: false)
  end

  defp create_email_message(to, subject, body) do
    message = """
    To: #{to}
    Subject: #{subject}
    Content-Type: text/plain; charset=utf-8

    #{body}
    """

    message
    |> Base.encode64()
    |> String.replace("+", "-")
    |> String.replace("/", "_")
    |> String.replace("=", "")
  end

  defp parse_calendar_event(event) do
    %{
      id: event["id"],
      title: event["summary"],
      description: event["description"],
      start_time: parse_calendar_datetime(event["start"]),
      end_time: parse_calendar_datetime(event["end"]),
      attendees: parse_attendees(event["attendees"]),
      location: event["location"],
      html_link: event["htmlLink"]
    }
  end

  defp parse_calendar_datetime(%{"dateTime" => datetime}) when is_binary(datetime) do
    case DateTime.from_iso8601(datetime) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_calendar_datetime(%{"date" => date}) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_calendar_datetime(_), do: nil

  defp parse_attendees(nil), do: []

  defp parse_attendees(attendees) when is_list(attendees) do
    Enum.map(attendees, fn attendee ->
      %{
        email: attendee["email"],
        name: attendee["displayName"],
        response_status: attendee["responseStatus"]
      }
    end)
  end

  defp build_calendar_event(params) do
    %{
      "summary" => params[:title] || params[:summary],
      "description" => params[:description],
      "start" => build_calendar_datetime(params[:start_time]),
      "end" => build_calendar_datetime(params[:end_time]),
      "attendees" => build_attendees(params[:attendees]),
      "location" => params[:location]
    }
  end

  defp build_calendar_datetime(datetime) when is_binary(datetime) do
    %{"dateTime" => datetime}
  end

  defp build_calendar_datetime(%DateTime{} = datetime) do
    %{"dateTime" => DateTime.to_iso8601(datetime)}
  end

  defp build_calendar_datetime(%NaiveDateTime{} = datetime) do
    %{"dateTime" => NaiveDateTime.to_iso8601(datetime) <> "Z"}
  end

  defp build_attendees(nil), do: nil

  defp build_attendees(attendees) when is_list(attendees) do
    Enum.map(attendees, fn email ->
      %{"email" => email}
    end)
  end

  defp extract_busy_times(events) do
    events
    |> Enum.filter(fn event -> event.start_time && event.end_time end)
    |> Enum.map(fn event -> {event.start_time, event.end_time} end)
    |> Enum.sort_by(fn {start_time, _} -> start_time end)
  end

  defp calculate_available_slots(start_time, end_time, busy_times, duration_minutes) do
    duration_seconds = duration_minutes * 60

    # Generate 30-minute slots
    slots = generate_time_slots(start_time, end_time, 30)

    # Filter out conflicting slots
    Enum.filter(slots, fn slot_start ->
      slot_end = DateTime.add(slot_start, duration_seconds, :second)
      not conflicts_with_busy_times?(slot_start, slot_end, busy_times)
    end)
  end

  defp generate_time_slots(start_time, end_time, interval_minutes) do
    interval_seconds = interval_minutes * 60

    Stream.unfold(start_time, fn current_time ->
      if DateTime.compare(current_time, end_time) == :lt do
        next_time = DateTime.add(current_time, interval_seconds, :second)
        {current_time, next_time}
      else
        nil
      end
    end)
    |> Enum.to_list()
  end

  defp conflicts_with_busy_times?(slot_start, slot_end, busy_times) do
    Enum.any?(busy_times, fn {busy_start, busy_end} ->
      DateTime.compare(slot_start, busy_end) == :lt and
        DateTime.compare(slot_end, busy_start) == :gt
    end)
  end

  # Message helpers for OpenAI

  @doc """
  Creates a user message for OpenAI chat completion.
  """
  def user_message(content), do: %{"role" => "user", "content" => content}

  @doc """
  Creates a system message for OpenAI chat completion.
  """
  def system_message(content), do: %{"role" => "system", "content" => content}

  @doc """
  Creates an assistant message for OpenAI chat completion.
  """
  def assistant_message(content), do: %{"role" => "assistant", "content" => content}
end
