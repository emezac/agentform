module GoogleIntegrationHelper
  def google_oauth_configured?
    GoogleSheets::ConfigService.oauth_configured?
  end

  def google_oauth_status_for_user(user)
    return :not_configured unless google_oauth_configured?
    return :not_connected unless user.google_integration.present?
    return :expired unless user.google_integration.valid_token?
    
    :connected
  end

  def google_oauth_status_message(status)
    case status
    when :not_configured
      "Google OAuth credentials need to be configured by an administrator."
    when :not_connected
      "Connect your Google account to enable Sheets integration."
    when :expired
      "Your Google connection has expired. Please reconnect."
    when :connected
      "Google Sheets integration is ready to use."
    else
      "Unknown status"
    end
  end

  def google_oauth_status_class(status)
    case status
    when :not_configured
      "bg-red-100 text-red-800"
    when :not_connected
      "bg-gray-100 text-gray-800"
    when :expired
      "bg-amber-100 text-amber-800"
    when :connected
      "bg-green-100 text-green-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end
end