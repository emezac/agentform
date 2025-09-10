class TrialExpirationCheckJob < ApplicationJob
  queue_as :default

  def perform
    check_expiring_trials
    check_expired_trials
  end

  private

  def check_expiring_trials
    # Find trials expiring in 3 days
    expiring_soon = User.where(
      subscription_status: 'trialing',
      trial_ends_at: 3.days.from_now.beginning_of_day..3.days.from_now.end_of_day
    )

    expiring_soon.find_each do |user|
      AdminNotificationService.notify(:trial_ending_soon, user: user)
    end
  end

  def check_expired_trials
    # Find trials that expired today
    expired_today = User.where(
      subscription_status: 'trialing',
      trial_ends_at: 1.day.ago.beginning_of_day..Time.current
    )

    expired_today.find_each do |user|
      AdminNotificationService.notify(:trial_expired, user: user)
      
      # Update user status
      user.update!(
        subscription_status: 'inactive',
        subscription_tier: 'basic'
      )
    end
  end
end