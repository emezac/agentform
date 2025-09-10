# frozen_string_literal: true

class GoogleTokenRefreshJob < ApplicationJob
  queue_as :default
  
  def perform
    GoogleIntegration.needs_refresh.find_each do |integration|
      result = GoogleSheets::TokenRefreshService.call(integration: integration)
      
      if result.failure?
        Rails.logger.warn "Failed to refresh token for user #{integration.user_id}: #{result.errors.join(', ')}"
      end
    end
  end
end