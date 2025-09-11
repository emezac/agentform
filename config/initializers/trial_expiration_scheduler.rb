# frozen_string_literal: true

# Trial Expiration Scheduler Configuration
# This initializer sets up the trial expiration job scheduling

Rails.application.configure do
  # Only configure in production
  if Rails.env.production?
    # Schedule trial expiration job to run daily
    # This should be configured in your deployment platform's scheduler
    
    Rails.logger.info "Trial expiration job configuration:"
    Rails.logger.info "  - Job should run daily at 9:00 AM UTC"
    Rails.logger.info "  - Configure in Heroku Scheduler or similar service"
    Rails.logger.info "  - Command: TrialExpirationJob.perform_now"
    
    # For Heroku, add this to your scheduler:
    # Frequency: Daily
    # Time: 09:00 UTC
    # Command: bundle exec rails runner 'TrialExpirationJob.perform_now'
    
    # Verify the job class exists
    if defined?(TrialExpirationJob)
      Rails.logger.info "  - TrialExpirationJob class is available"
    else
      Rails.logger.warn "  - TrialExpirationJob class not found - create it if needed"
    end
  end
end