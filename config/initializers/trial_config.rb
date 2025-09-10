# frozen_string_literal: true

# Configuration for trial period management
class TrialConfig
  DEFAULT_TRIAL_DAYS = 14

  class << self
    # Get the configured trial period in days
    def trial_period_days
      @trial_period_days ||= begin
        days = ENV['TRIAL_PERIOD_DAYS']&.to_i
        if days && days >= 0
          Rails.logger.info "Trial period configured: #{days} days"
          days
        else
          if ENV['TRIAL_PERIOD_DAYS'].present?
            Rails.logger.warn "Invalid TRIAL_PERIOD_DAYS: #{ENV['TRIAL_PERIOD_DAYS']}, using default: #{DEFAULT_TRIAL_DAYS}"
          end
          DEFAULT_TRIAL_DAYS
        end
      end
    end

    # Check if trial functionality is enabled
    def trial_enabled?
      # Check TRIAL_ON environment variable first, then fallback to trial_period_days > 0
      if ENV['TRIAL_ON'].present?
        ENV['TRIAL_ON'].downcase.in?(['true', '1', 'yes', 'on'])
      else
        trial_period_days > 0
      end
    end

    # Reset cached configuration (useful for testing)
    def reset!
      @trial_period_days = nil
    end

    # Get trial end date for a given start date
    def trial_end_date(start_date = Time.current)
      return nil unless trial_enabled?
      start_date + trial_period_days.days
    end

    # Human readable trial period description
    def trial_description
      if trial_enabled?
        "#{trial_period_days} day#{trial_period_days == 1 ? '' : 's'}"
      else
        "No trial period"
      end
    end
  end
end

# Log the current configuration on startup
Rails.logger.info "TrialConfig initialized: #{TrialConfig.trial_description}"