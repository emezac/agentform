# frozen_string_literal: true

class TrialExpirationJob < ApplicationJob
  queue_as :default

  def perform
    # Find users whose trial expires today
    expiring_today = User.where(
      subscription_status: 'trialing',
      trial_ends_at: Date.current.beginning_of_day..Date.current.end_of_day
    )

    expiring_today.find_each do |user|
      # Send expiration warning email
      UserMailer.trial_expiring_today(user).deliver_now
      Rails.logger.info "Trial expiring today for user: #{user.email}"
    end

    # Find users whose trial expired yesterday (grace period)
    expired_yesterday = User.where(
      subscription_status: 'trialing',
      trial_ends_at: 1.day.ago.beginning_of_day..1.day.ago.end_of_day
    )

    expired_yesterday.find_each do |user|
      # Downgrade user to basic tier
      user.update!(
        subscription_tier: 'basic',
        subscription_status: 'expired'
      )
      
      # Send trial expired email with upgrade link
      UserMailer.trial_expired(user).deliver_now
      Rails.logger.info "Trial expired for user: #{user.email}, downgraded to basic"
    end

    # Find users whose trial expires in 3 days (early warning)
    expiring_in_3_days = User.where(
      subscription_status: 'trialing',
      trial_ends_at: 3.days.from_now.beginning_of_day..3.days.from_now.end_of_day
    )

    expiring_in_3_days.find_each do |user|
      # Send early warning email
      UserMailer.trial_expiring_soon(user).deliver_now
      Rails.logger.info "Trial expiring in 3 days for user: #{user.email}"
    end
  end
end