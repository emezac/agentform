# frozen_string_literal: true

# Current context for tracking request-scoped data
# This provides a thread-safe way to access the current user and other request data
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :request_id, :user_agent, :ip_address, :api_token

  # Convenience methods
  def user_id
    user&.id
  end

  def authenticated?
    user.present?
  end

  def admin?
    user&.admin?
  end

  def premium?
    user&.premium? || user&.admin?
  end

  # Reset callback to ensure clean state between requests
  resets do
    Time.zone = nil
  end
end