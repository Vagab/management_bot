defmodule FinanceChatIntegration.Integrations.HubspotClient do
  @moduledoc """
  HubSpot API client for managing contacts and CRM data.
  """

  @hubspot_api_base "https://api.hubapi.com"

  @doc """
  Fetches all contacts for a user.
  """
  def fetch_contacts(access_token, _opts \\ []) do
    url = "#{@hubspot_api_base}/crm/v3/objects/contacts"
    headers = [{"Authorization", "Bearer #{access_token}"}]

    params = [
      {"limit", "100"},
      {"properties", "email,firstname,lastname,company,phone,jobtitle,lifecyclestage"}
    ]

    case Req.get(url, headers: headers, params: params) do
      {:ok, %{status: 200, body: response}} ->
        contacts = response["results"] || []
        parsed_contacts = Enum.map(contacts, &parse_contact/1)
        {:ok, parsed_contacts}

      {:ok, %{status: status, body: error}} ->
        {:error, %{status: status, error: error}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Searches for contacts by email.
  """
  def search_contacts_by_email(access_token, email) do
    url = "#{@hubspot_api_base}/crm/v3/objects/contacts/search"

    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
    ]

    body = %{
      "filterGroups" => [
        %{
          "filters" => [
            %{
              "propertyName" => "email",
              "operator" => "EQ",
              "value" => email
            }
          ]
        }
      ],
      "properties" => ["email", "firstname", "lastname", "company", "phone", "jobtitle"]
    }

    case Req.post(url, headers: headers, json: body) do
      {:ok, %{status: 200, body: response}} ->
        contacts = response["results"] || []
        parsed_contacts = Enum.map(contacts, &parse_contact/1)
        {:ok, parsed_contacts}

      {:ok, %{status: status, body: error}} ->
        {:error, %{status: status, error: error}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Creates a new contact in HubSpot.
  """
  def create_contact(access_token, contact_params) do
    url = "#{@hubspot_api_base}/crm/v3/objects/contacts"

    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
    ]

    body = %{
      "properties" => build_contact_properties(contact_params)
    }

    case Req.post(url, headers: headers, json: body) do
      {:ok, %{status: 201, body: response}} ->
        {:ok, parse_contact(response)}

      {:ok, %{status: status, body: error}} ->
        {:error, %{status: status, error: error}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Updates an existing contact in HubSpot.
  """
  def update_contact(access_token, contact_id, contact_params) do
    url = "#{@hubspot_api_base}/crm/v3/objects/contacts/#{contact_id}"

    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
    ]

    body = %{
      "properties" => build_contact_properties(contact_params)
    }

    case Req.patch(url, headers: headers, json: body) do
      {:ok, %{status: 200, body: response}} ->
        {:ok, parse_contact(response)}

      {:ok, %{status: status, body: error}} ->
        {:error, %{status: status, error: error}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Creates a note for a contact.
  """
  def create_contact_note(access_token, contact_id, note_body) do
    # First create the note
    url = "#{@hubspot_api_base}/crm/v3/objects/notes"

    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
    ]

    body = %{
      "properties" => %{
        "hs_note_body" => note_body,
        "hs_timestamp" => DateTime.utc_now() |> DateTime.to_unix(:millisecond)
      }
    }

    case Req.post(url, headers: headers, json: body) do
      {:ok, %{status: 201, body: note_response}} ->
        note_id = note_response["id"]

        # Associate the note with the contact
        case associate_note_with_contact(access_token, note_id, contact_id) do
          :ok -> {:ok, %{id: note_id, body: note_body}}
          error -> error
        end

      {:ok, %{status: status, body: error}} ->
        {:error, %{status: status, error: error}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp parse_contact(contact) do
    properties = contact["properties"] || %{}

    %{
      id: contact["id"],
      email: properties["email"],
      first_name: properties["firstname"],
      last_name: properties["lastname"],
      company: properties["company"],
      phone: properties["phone"],
      job_title: properties["jobtitle"],
      lifecycle_stage: properties["lifecyclestage"]
    }
  end

  defp build_contact_properties(params) do
    properties = %{}

    # Handle both atom keys (from internal calls) and string keys (from tools)
    email = params[:email] || params["email"]
    first_name = params[:first_name] || params[:firstname] || params["firstname"]
    last_name = params[:last_name] || params[:lastname] || params["lastname"]
    company = params[:company] || params["company"]
    phone = params[:phone] || params["phone"]
    job_title = params[:job_title] || params["jobtitle"]

    properties =
      if email, do: Map.put(properties, "email", email), else: properties

    properties =
      if first_name,
        do: Map.put(properties, "firstname", first_name),
        else: properties

    properties =
      if last_name,
        do: Map.put(properties, "lastname", last_name),
        else: properties

    properties =
      if company, do: Map.put(properties, "company", company), else: properties

    properties =
      if phone, do: Map.put(properties, "phone", phone), else: properties

    properties =
      if job_title,
        do: Map.put(properties, "jobtitle", job_title),
        else: properties

    properties
  end

  defp associate_note_with_contact(access_token, note_id, contact_id) do
    url =
      "#{@hubspot_api_base}/crm/v3/objects/notes/#{note_id}/associations/contacts/#{contact_id}/note_to_contact"

    headers = [{"Authorization", "Bearer #{access_token}"}]

    case Req.put(url, headers: headers) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: status, body: error}} -> {:error, %{status: status, error: error}}
      {:error, reason} -> {:error, reason}
    end
  end
end
