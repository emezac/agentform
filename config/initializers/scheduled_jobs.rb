# frozen_string_literal: true

# Schedule recurring jobs for production
Rails.application.configure do
  # Schedule trial expiration job to run daily at 9 AM UTC
  # This will be handled by Heroku Scheduler in production
  # For local development, you can run: rails runner 'TrialExpirationJob.perform_now'
  
  if Rails.env.production?
    Rails.logger.info "Trial expiration job should be scheduled to run daily in production"
    Rails.logger.info "Example cron entry: 0 9 * * * cd /path/to/app && bundle exec rails runner 'TrialExpirationJob.perform_now'"
  end
end