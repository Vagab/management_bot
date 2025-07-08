defmodule FinanceChatIntegrationWeb.HubspotController do
  use FinanceChatIntegrationWeb, :controller
  alias FinanceChatIntegration.Accounts
  alias FinanceChatIntegration.Hubspot

  # This plug ensures a user is logged in before they can connect to HubSpot
  plug :require_authenticated_user

  # Action #1: Start the flow
  def connect(conn, _params) do
    # Generate a random string for CSRF protection
    state = :crypto.strong_rand_bytes(24) |> Base.url_encode64()

    # Call our context to get the URL
    authorize_url =
      Hubspot.authorize_url!(
        scope: "crm.objects.contacts.read crm.objects.contacts.write oauth",
        state: state
      )

    conn
    # Store the state for later verification
    |> put_session(:oauth2_state, state)
    |> redirect(external: authorize_url)
  end

  # Action #2: Handle the callback from HubSpot
  def callback(conn, %{"code" => code, "state" => state}) do
    # 1. Verify the state to prevent CSRF attacks
    case get_session(conn, :oauth2_state) do
      ^state ->
        # State is valid, proceed.
        # Clean the state out of the session now that we've used it.
        conn = put_session(conn, :oauth2_state, nil)
        process_token(conn, code)

      _ ->
        # State is invalid or missing
        conn
        |> put_flash(:error, "Invalid session state. Please try connecting again.")
        |> redirect(to: ~p"/chat")
    end
  end

  def callback(conn, %{"error" => _error, "error_description" => desc}) do
    conn
    |> put_flash(:error, "HubSpot login failed: #{desc}")
    |> redirect(to: ~p"/chat")
  end

  # Handle malformed callback
  def callback(conn, _params) do
    conn
    |> put_flash(:error, "Invalid HubSpot callback parameters")
    |> redirect(to: ~p"/chat")
  end

  # --- Private Helper Functions ---

  defp process_token(conn, code) do
    try do
      token = Jason.decode!(Hubspot.get_token!(code).access_token)

      {:ok, _user} = Accounts.link_hubspot_account(conn.assigns.current_user, token)

      conn
      |> put_flash(:info, "HubSpot account connected successfully!")
      |> redirect(to: ~p"/chat")
    rescue
      # If `get_token!` fails, it raises an error. We can rescue it.
      e in OAuth2.Error ->
        conn
        |> put_flash(:error, "Error retrieving HubSpot token: #{inspect(e.reason)}")
        |> redirect(to: ~p"/chat")
    end
  end

  # Import the authentication plug
  defp require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to connect HubSpot")
      |> redirect(to: ~p"/users/log_in")
      |> halt()
    end
  end
end
