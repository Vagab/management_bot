defmodule FinanceChatIntegration.Hubspot do
  @moduledoc """
  HubSpot OAuth2 integration context.

  This module handles all HubSpot OAuth2 operations including
  generating authorization URLs and exchanging codes for tokens.
  """

  defp client do
    # Manually fetch the configuration from config/config.exs
    config = Application.fetch_env!(:oauth2, :hubspot_provider)

    OAuth2.Client.new(
      strategy: OAuth2.Strategy.AuthCode,
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      site: "https://api.hubapi.com",
      authorize_url: config[:authorize_url],
      token_url: config[:token_url],
      redirect_uri: config[:redirect_uri]
    )
  end

  @doc """
  Generates the authorization URL to redirect the user to.
  It's the starting point of the OAuth flow.
  """
  def authorize_url!(params) do
    # We pass scope and state in from the controller.
    # The `!` means it will raise an error on failure.
    OAuth2.Client.authorize_url!(client(), params)
  end

  @doc """
  Exchanges an authorization `code` for an access token.
  This is the core of the callback logic.
  """
  def get_token!(code) do
    # THIS IS THE KEY FIX: We pass the `redirect_uri` in the options.
    # The `!` version will raise on failure, which the controller can handle.
    OAuth2.Client.get_token!(client(), code: code, client_secret: client().client_secret).token
  end
end
