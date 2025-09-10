# Recurring Jobs Configuration for AgentForm
# This initializer sets up recurring background jobs using Sidekiq

if defined?(Sidekiq) && Rails.env.production?
  # Schedule recurring jobs only in production
  # In development, these can be run manually for testing
  
  Rails.application.config.after_initialize do
    # Schedule trial expiration checks daily at 9 AM UTC
    Sidekiq::Cron::Job.load_from_hash({
      'trial_expiration_check' => {
        'cron' => '0 9 * * *',  # Daily at 9 AM UTC
        'class' => 'TrialExpirationCheckJob',
        'queue' => 'default'
      }
    }) if defined?(Sidekiq::Cron)

    # Schedule response volume checks every hour
    Sidekiq::Cron::Job.load_from_hash({
      'response_volume_check' => {
        'cron' => '0 * * * *',  # Every hour
        'class' => 'ResponseVolumeCheckJob',
        'queue' => 'default'
      }
    }) if defined?(Sidekiq::Cron)

    # Clean up old notifications weekly on Sundays at 2 AM UTC
    Sidekiq::Cron::Job.load_from_hash({
      'notification_cleanup' => {
        'cron' => '0 2 * * 0',  # Sundays at 2 AM UTC
        'class' => 'NotificationCleanupJob',
        'queue' => 'default'
      }
    }) if defined?(Sidekiq::Cron)

    Rails.logger.info "Recurring jobs scheduled successfully" if defined?(Sidekiq::Cron)
  end
end

# For development and testing, provide manual job execution methods
unless Rails.env.production?
  class RecurringJobsHelper
    def self.run_trial_expiration_check
      TrialExpirationCheckJob.perform_now
    end

    def self.run_response_volume_check
      ResponseVolumeCheckJob.perform_now
    end

    def self.run_notification_cleanup
      NotificationCleanupJob.perform_now
    end

    def self.run_all_checks
      run_trial_expiration_check
      run_response_volume_check
      puts "✅ All recurring jobs executed manually"
    end
  end

  Rails.logger.info "Recurring jobs helper available: RecurringJobsHelper.run_all_checks"
end