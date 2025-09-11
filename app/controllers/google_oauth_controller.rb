class GoogleOauthController < ApplicationController
  before_action :authenticate_user!

  def connect
    # Authorize that user can create a Google integration
    authorize GoogleIntegration.new(user: current_user), :create?
    
    begin
      # Generate OAuth2 authorization URL
      client = oauth_client
      
      # Store state parameter to prevent CSRF
      session[:google_oauth_state] = SecureRandom.hex(16)
      
      auth_url = client.authorization_uri(
        scope: google_scopes.join(' '),
        state: session[:google_oauth_state],
        access_type: 'offline',
        prompt: 'consent' # Force consent to get refresh token
      ).to_s

      redirect_to auth_url, allow_other_host: true
    rescue => e
      Rails.logger.error "Google OAuth connect error: #{e.message}"
      redirect_to profile_path, alert: "Google OAuth configuration error. Please contact support."
    end
  end

  def callback
    # Authorize that user can create/update a Google integration
    authorize GoogleIntegration.new(user: current_user), :create?
    
    # Verify state parameter
    if params[:state] != session[:google_oauth_state]
      redirect_to profile_path, alert: 'Invalid OAuth state. Please try again.'
      return
    end

    # Handle OAuth errors
    if params[:error].present?
      error_message = case params[:error]
      when 'access_denied'
        'You denied access to Google Sheets. Please authorize to continue.'
      else
        "OAuth error: #{params[:error]}"
      end
      
      redirect_to profile_path, alert: error_message
      return
    end

    # Exchange authorization code for tokens
    begin
      client = oauth_client
      client.code = params[:code]
      client.fetch_access_token!

      # Get user info to verify the connection
      user_info = fetch_google_user_info(client.access_token)

      # Create or update Google integration
      integration = current_user.google_integration || current_user.build_google_integration
      
      integration.update!(
        access_token: client.access_token,
        refresh_token: client.refresh_token,
        token_expires_at: Time.current + client.expires_in.seconds,
        scope: google_scopes.join(' '),
        user_info: user_info,
        active: true,
        last_used_at: Time.current,
        usage_count: (integration.usage_count || 0) + 1,
        error_log: []
      )

      redirect_to profile_path, notice: 'Successfully connected to Google Sheets!'
      
    rescue => e
      Rails.logger.error "Google OAuth callback error: #{e.message}"
      redirect_to profile_path, alert: 'Failed to connect to Google. Please try again.'
    end
  ensure
    # Clear the state from session
    session.delete(:google_oauth_state)
  end

  def disconnect
    integration = current_user.google_integration
    
    if integration
      integration.revoke!
      redirect_to profile_path, notice: 'Disconnected from Google Sheets.'
    else
      redirect_to profile_path, alert: 'No Google connection found.'
    end
  end

  def status
    integration = current_user.google_integration
    
    render json: {
      connected: integration&.valid_token? || false,
      user_info: integration&.user_info,
      last_used: integration&.last_used_at,
      expires_at: integration&.token_expires_at,
      error: integration&.error_log&.last
    }
  end

  private

  def oauth_client
    unless GoogleSheets::ConfigService.oauth_configured?
      raise "Google OAuth credentials not configured. Please configure GOOGLE_SHEETS_CLIENT_ID and GOOGLE_SHEETS_CLIENT_SECRET environment variables for production, or google_sheets_integration in Rails credentials for development."
    end
    
    Signet::OAuth2::Client.new(
      client_id: GoogleSheets::ConfigService.oauth_client_id,
      client_secret: GoogleSheets::ConfigService.oauth_client_secret,
      authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      redirect_uri: google_oauth_callback_url
    )
  rescue => e
    Rails.logger.error "OAuth client configuration error: #{e.message}"
    raise e
  end

  def google_scopes
    [
      'https://www.googleapis.com/auth/spreadsheets',
      'https://www.googleapis.com/auth/userinfo.email'
    ]
  end

  def google_oauth_callback_url
    url_for(controller: 'google_oauth', action: 'callback', host: request.host_with_port, protocol: request.protocol)
  end

  def fetch_google_user_info(access_token)
    uri = URI('https://www.googleapis.com/oauth2/v2/userinfo')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{access_token}"

    response = http.request(request)
    
    if response.code == '200'
      JSON.parse(response.body)
    else
      raise "Failed to fetch user info: #{response.code}"
    end
  end
end