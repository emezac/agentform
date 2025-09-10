# frozen_string_literal: true

module Ai
  class RateLimitingService
    def initialize(user_id:, action:, ip_address: nil)
      @user_id = user_id
      @action = action
      @ip_address = ip_address
    end

    def check_rate_limit
      # For now, always allow - implement proper rate limiting later
      {
        success: true,
        remaining_requests: 100,
        reset_time: 1.hour.from_now
      }
    end

    private

    attr_reader :user_id, :action, :ip_address
  end
end