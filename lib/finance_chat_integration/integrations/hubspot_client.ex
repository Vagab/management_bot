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

    properties =
      if params[:email], do: Map.put(properties, "email", params[:email]), else: properties

    properties =
      if params[:first_name],
        do: Map.put(properties, "firstname", params[:first_name]),
        else: properties

    properties =
      if params[:last_name],
        do: Map.put(properties, "lastname", params[:last_name]),
        else: properties

    properties =
      if params[:company], do: Map.put(properties, "company", params[:company]), else: properties

    properties =
      if params[:phone], do: Map.put(properties, "phone", params[:phone]), else: properties

    properties =
      if params[:job_title],
        do: Map.put(properties, "jobtitle", params[:job_title]),
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
