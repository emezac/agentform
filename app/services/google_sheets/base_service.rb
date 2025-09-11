# frozen_string_literal: true

module GoogleSheets
  class BaseService
    include ServiceObject
    
    private
    
    def google_client(integration)
      @google_client ||= begin
        client = Google::Apis::SheetsV4::SheetsService.new
        client.authorization = build_authorization(integration)
        client
      end
    end
    
    def build_authorization(integration)
      # Verificar y refrescar token si es necesario
      integration.refresh_token! if integration.needs_refresh?
      
      auth = Signet::OAuth2::Client.new(
        access_token: integration.access_token,
        refresh_token: integration.refresh_token,
        client_id: GoogleSheets::ConfigService.oauth_client_id,
        client_secret: GoogleSheets::ConfigService.oauth_client_secret
      )
      
      auth
    end
    
    def with_rate_limiting(&block)
      rate_limiter = RateLimiter.new("google_sheets:#{@user.id}")
      rate_limiter.execute(&block)
    end
    
    def handle_google_api_error(error)
      case error
      when Google::Apis::AuthorizationError
        @integration&.update!(active: false)
        ServiceResult.failure("Google authorization expired. Please reconnect your account.")
      when Google::Apis::RateLimitError
        ServiceResult.failure("Rate limit exceeded. Please try again later.")
      when Google::Apis::ClientError
        ServiceResult.failure("Google API error: #{error.message}")
      else
        ServiceResult.failure("Unexpected error: #{error.message}")
      end
    end
  end
end