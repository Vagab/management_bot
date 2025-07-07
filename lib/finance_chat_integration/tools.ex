defmodule FinanceChatIntegration.Tools do
  @moduledoc """
  Tool definitions and execution for LLM function calling.

  This module provides:
  - Tool schema definitions for OpenAI function calling
  - Tool execution functions that call existing integrations
  - Error handling and response formatting
  """

  alias FinanceChatIntegration.{Integrations, Content.VectorSearch}

  @doc """
  Returns the list of available tool definitions for OpenAI function calling.
  """
  def tool_definitions do
    [
      search_data_tool(),
      search_contacts_tool(),
      get_contact_details_tool(),
      create_hubspot_contact_tool(),
      update_hubspot_contact_tool(),
      send_email_tool(),
      search_calendar_tool(),
      get_email_details_tool(),
      create_calendar_event_tool()
    ]
  end

  @doc """
  Executes a tool call and returns the result.
  """
  def execute_tool(tool_name, args, user) do
    case tool_name do
      "search_data" -> execute_search_data(args, user)
      "search_contacts" -> execute_search_contacts(args, user)
      "get_contact_details" -> execute_get_contact_details(args, user)
      "create_hubspot_contact" -> execute_create_hubspot_contact(args, user)
      "update_hubspot_contact" -> execute_update_hubspot_contact(args, user)
      "send_email" -> execute_send_email(args, user)
      "search_calendar" -> execute_search_calendar(args, user)
      "get_email_details" -> execute_get_email_details(args, user)
      "create_calendar_event" -> execute_create_calendar_event(args, user)
      _ -> {:error, "Unknown tool: #{tool_name}"}
    end
  end

  # Tool Definitions

  defp search_data_tool do
    %{
      "type" => "function",
      "function" => %{
        "name" => "search_data",
        "description" =>
          "Search through the user's content (emails, contacts, calendar) using semantic similarity",
        "parameters" => %{
          "type" => "object",
          "properties" => %{
            "query" => %{
              "type" => "string",
              "description" => "The search query to find relevant information"
            },
            "source_filter" => %{
              "type" => "string",
              "enum" => ["gmail", "hubspot", "calendar"],
              "description" => "Optional filter to search only specific content source"
            },
            "limit" => %{
              "type" => "integer",
              "description" => "Maximum number of results to return (default: 5)"
            }
          },
          "required" => ["query"]
        }
      }
    }
  end

  defp search_contacts_tool do
    %{
      "type" => "function",
      "function" => %{
        "name" => "search_contacts",
        "description" => "Search for contacts in HubSpot CRM",
        "parameters" => %{
          "type" => "object",
          "properties" => %{
            "query" => %{
              "type" => "string",
              "description" => "Search term for finding contacts (name, email, company)"
            }
          },
          "required" => ["query"]
        }
      }
    }
  end

  defp get_contact_details_tool do
    %{
      "type" => "function",
      "function" => %{
        "name" => "get_contact_details",
        "description" => "Get detailed information about a specific contact from HubSpot",
        "parameters" => %{
          "type" => "object",
          "properties" => %{
            "contact_id" => %{
              "type" => "string",
              "description" => "HubSpot contact ID"
            }
          },
          "required" => ["contact_id"]
        }
      }
    }
  end

  defp create_hubspot_contact_tool do
    %{
      "type" => "function",
      "function" => %{
        "name" => "create_hubspot_contact",
        "description" => "Create a new contact in HubSpot CRM",
        "parameters" => %{
          "type" => "object",
          "properties" => %{
            "email" => %{
              "type" => "string",
              "description" => "Contact email address"
            },
            "first_name" => %{
              "type" => "string",
              "description" => "Contact first name"
            },
            "last_name" => %{
              "type" => "string",
              "description" => "Contact last name"
            },
            "company" => %{
              "type" => "string",
              "description" => "Contact company name"
            },
            "phone" => %{
              "type" => "string",
              "description" => "Contact phone number"
            }
          },
          "required" => ["email"]
        }
      }
    }
  end

  defp update_hubspot_contact_tool do
    %{
      "type" => "function",
      "function" => %{
        "name" => "update_hubspot_contact",
        "description" => "Update an existing contact in HubSpot CRM",
        "parameters" => %{
          "type" => "object",
          "properties" => %{
            "contact_id" => %{
              "type" => "string",
              "description" => "HubSpot contact ID"
            },
            "email" => %{
              "type" => "string",
              "description" => "Contact email address"
            },
            "first_name" => %{
              "type" => "string",
              "description" => "Contact first name"
            },
            "last_name" => %{
              "type" => "string",
              "description" => "Contact last name"
            },
            "company" => %{
              "type" => "string",
              "description" => "Contact company name"
            },
            "phone" => %{
              "type" => "string",
              "description" => "Contact phone number"
            }
          },
          "required" => ["contact_id"]
        }
      }
    }
  end

  defp send_email_tool do
    %{
      "type" => "function",
      "function" => %{
        "name" => "send_email",
        "description" => "Send an email via Gmail",
        "parameters" => %{
          "type" => "object",
          "properties" => %{
            "to" => %{
              "type" => "string",
              "description" => "Recipient email address"
            },
            "subject" => %{
              "type" => "string",
              "description" => "Email subject line"
            },
            "body" => %{
              "type" => "string",
              "description" => "Email body content"
            }
          },
          "required" => ["to", "subject", "body"]
        }
      }
    }
  end

  defp search_calendar_tool do
    %{
      "type" => "function",
      "function" => %{
        "name" => "search_calendar",
        "description" => "Search calendar events and find available time slots",
        "parameters" => %{
          "type" => "object",
          "properties" => %{
            "time_min" => %{
              "type" => "string",
              "description" => "Start time for search in ISO 8601 format (optional)"
            },
            "time_max" => %{
              "type" => "string",
              "description" => "End time for search in ISO 8601 format (optional)"
            },
            "query" => %{
              "type" => "string",
              "description" => "Search term for finding specific events (optional)"
            }
          },
          "required" => []
        }
      }
    }
  end

  defp get_email_details_tool do
    %{
      "type" => "function",
      "function" => %{
        "name" => "get_email_details",
        "description" => "Get detailed information about specific emails from Gmail",
        "parameters" => %{
          "type" => "object",
          "properties" => %{
            "query" => %{
              "type" => "string",
              "description" => "Gmail search query to find specific emails"
            }
          },
          "required" => ["query"]
        }
      }
    }
  end

  defp create_calendar_event_tool do
    %{
      "type" => "function",
      "function" => %{
        "name" => "create_calendar_event",
        "description" => "Create a new calendar event",
        "parameters" => %{
          "type" => "object",
          "properties" => %{
            "title" => %{
              "type" => "string",
              "description" => "Event title/summary"
            },
            "description" => %{
              "type" => "string",
              "description" => "Event description (optional)"
            },
            "start_time" => %{
              "type" => "string",
              "description" => "Start time in ISO 8601 format"
            },
            "end_time" => %{
              "type" => "string",
              "description" => "End time in ISO 8601 format"
            },
            "attendees" => %{
              "type" => "array",
              "items" => %{"type" => "string"},
              "description" => "List of attendee email addresses (optional)"
            },
            "location" => %{
              "type" => "string",
              "description" => "Event location (optional)"
            }
          },
          "required" => ["title", "start_time", "end_time"]
        }
      }
    }
  end

  # Tool Execution Functions

  defp execute_search_data(args, user) do
    query = args["query"]
    source_filter = args["source_filter"]
    limit = args["limit"] || 5

    opts = [limit: limit]
    opts = if source_filter, do: Keyword.put(opts, :source_filter, source_filter), else: opts

    case VectorSearch.search_for_context(query, user.id, opts) do
      {:ok, results} ->
        formatted_results = format_search_results(results)

        {:ok,
         %{
           "status" => "success",
           "results" => formatted_results,
           "count" => length(results)
         }}

      {:error, reason} ->
        {:error, "Search failed: #{inspect(reason)}"}
    end
  end

  defp execute_search_contacts(args, user) do
    query = args["query"]

    case Integrations.fetch_hubspot_contacts(user, search: query) do
      {:ok, contacts} ->
        formatted_contacts = format_contacts(contacts)

        {:ok,
         %{
           "status" => "success",
           "contacts" => formatted_contacts,
           "count" => length(contacts)
         }}

      {:error, reason} ->
        {:error, "Contact search failed: #{inspect(reason)}"}
    end
  end

  defp execute_get_contact_details(args, user) do
    contact_id = args["contact_id"]

    case Integrations.fetch_hubspot_contacts(user, search: contact_id) do
      {:ok, [contact | _]} ->
        formatted_contact = format_contact(contact)

        {:ok,
         %{
           "status" => "success",
           "contact" => formatted_contact
         }}

      {:ok, []} ->
        {:error, "Contact not found"}

      {:error, reason} ->
        {:error, "Failed to get contact details: #{inspect(reason)}"}
    end
  end

  defp execute_create_hubspot_contact(args, user) do
    contact_params =
      %{
        email: args["email"],
        firstname: args["first_name"],
        lastname: args["last_name"],
        company: args["company"],
        phone: args["phone"]
      }
      |> Enum.filter(fn {_key, value} -> value != nil end)
      |> Enum.into(%{})

    case Integrations.create_hubspot_contact(user, contact_params) do
      {:ok, contact} ->
        {:ok,
         %{
           "status" => "success",
           "message" => "Contact created successfully",
           "contact" => format_contact(contact)
         }}

      {:error, reason} ->
        {:error, "Failed to create contact: #{inspect(reason)}"}
    end
  end

  defp execute_update_hubspot_contact(args, user) do
    contact_id = args["contact_id"]

    update_params =
      %{
        email: args["email"],
        firstname: args["first_name"],
        lastname: args["last_name"],
        company: args["company"],
        phone: args["phone"]
      }
      |> Enum.filter(fn {_key, value} -> value != nil end)
      |> Enum.into(%{})

    case Integrations.update_hubspot_contact(user, contact_id, update_params) do
      {:ok, contact} ->
        {:ok,
         %{
           "status" => "success",
           "message" => "Contact updated successfully",
           "contact" => format_contact(contact)
         }}

      {:error, reason} ->
        {:error, "Failed to update contact: #{inspect(reason)}"}
    end
  end

  defp execute_send_email(args, user) do
    email_params = %{
      to: args["to"],
      subject: args["subject"],
      body: args["body"]
    }

    case Integrations.send_email(user, email_params) do
      {:ok, response} ->
        {:ok,
         %{
           "status" => "success",
           "message" => "Email sent successfully",
           "message_id" => response["id"]
         }}

      {:error, reason} ->
        {:error, "Failed to send email: #{inspect(reason)}"}
    end
  end

  defp execute_search_calendar(args, user) do
    opts = []
    opts = if args["time_min"], do: Keyword.put(opts, :time_min, args["time_min"]), else: opts
    opts = if args["time_max"], do: Keyword.put(opts, :time_max, args["time_max"]), else: opts

    case Integrations.fetch_calendar_events(user, opts) do
      {:ok, events} ->
        # Filter events by query if provided
        filtered_events =
          if args["query"] do
            query = String.downcase(args["query"])

            Enum.filter(events, fn event ->
              title = String.downcase(event.title || "")
              description = String.downcase(event.description || "")
              String.contains?(title, query) or String.contains?(description, query)
            end)
          else
            events
          end

        formatted_events = format_calendar_events(filtered_events)

        {:ok,
         %{
           "status" => "success",
           "events" => formatted_events,
           "count" => length(filtered_events)
         }}

      {:error, reason} ->
        {:error, "Calendar search failed: #{inspect(reason)}"}
    end
  end

  defp execute_get_email_details(args, user) do
    query = args["query"]

    case Integrations.fetch_emails(user, query: query) do
      {:ok, emails} ->
        formatted_emails = format_emails(emails)

        {:ok,
         %{
           "status" => "success",
           "emails" => formatted_emails,
           "count" => length(emails)
         }}

      {:error, reason} ->
        {:error, "Email fetch failed: #{inspect(reason)}"}
    end
  end

  defp execute_create_calendar_event(args, user) do
    event_params =
      [
        title: args["title"],
        description: args["description"],
        start_time: args["start_time"],
        end_time: args["end_time"],
        attendees: args["attendees"],
        location: args["location"]
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    case Integrations.create_calendar_event(user, event_params) do
      {:ok, event} ->
        {:ok,
         %{
           "status" => "success",
           "message" => "Calendar event created successfully",
           "event" => format_calendar_event(event)
         }}

      {:error, reason} ->
        {:error, "Failed to create calendar event: #{inspect(reason)}"}
    end
  end

  # Result Formatting Functions

  defp format_search_results(results) do
    Enum.map(results, fn result ->
      %{
        "content" => result.content,
        "source" => result.source,
        "similarity" => result.similarity,
        "timestamp" => result.timestamp
      }
    end)
  end

  defp format_contacts(contacts) when is_list(contacts) do
    Enum.map(contacts, &format_contact/1)
  end

  defp format_contact(contact), do: contact

  defp format_emails(emails) do
    Enum.map(emails, fn email ->
      %{
        "id" => email.id,
        "subject" => email.subject,
        "from" => email.from,
        "to" => email.to,
        "date" => email.date,
        "snippet" => email.snippet,
        # Truncate long bodies
        "body" => String.slice(email.body || "", 0, 500)
      }
    end)
  end

  defp format_calendar_events(events) do
    Enum.map(events, &format_calendar_event/1)
  end

  defp format_calendar_event(event) do
    %{
      "id" => event.id,
      "title" => event.title,
      "description" => event.description,
      "start_time" => format_datetime(event.start_time),
      "end_time" => format_datetime(event.end_time),
      "attendees" => event.attendees || [],
      "location" => event.location
    }
  end

  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_datetime(%Date{} = date), do: Date.to_iso8601(date)
  defp format_datetime(nil), do: nil
  defp format_datetime(other), do: other
end
