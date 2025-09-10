# frozen_string_literal: true

# Schedule trial expiration job to run daily
# This will check for expiring trials and handle notifications/downgrades

if Rails.env.production? || Rails.env.staging?
  # In production, you would typically use a cron job or scheduler like whenever gem
  # For now, we'll just log that this should be set up
  Rails.logger.info "Trial expiration job should be scheduled to run daily in production"
  Rails.logger.info "Example cron entry: 0 9 * * * cd /path/to/app && bundle exec rails runner 'TrialExpirationJob.perform_now'"
end

# For development/testing, you can manually trigger with:
# TrialExpirationJob.perform_now