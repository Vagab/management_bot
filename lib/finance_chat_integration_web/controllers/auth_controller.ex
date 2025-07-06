defmodule FinanceChatIntegrationWeb.AuthController do
  use FinanceChatIntegrationWeb, :controller
  alias FinanceChatIntegration.Accounts
  alias FinanceChatIntegrationWeb.UserAuth

  # This plug is provided by ueberauth
  plug Ueberauth

  # The callback action that handles the response from Google
  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case Accounts.find_or_create_by_oauth(auth) do
      {:ok, user} ->
        conn
        # Using the function from phx.gen.auth
        |> UserAuth.log_in_user(user)
        |> put_flash(:info, "Logged in successfully.")
        |> redirect(to: ~p"/")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Error logging in. Please try again.")
        |> redirect(to: ~p"/users/log_in")
    end
  end

  # Handle OAuth failures
  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate with OAuth provider.")
    |> redirect(to: ~p"/users/log_in")
  end
end
