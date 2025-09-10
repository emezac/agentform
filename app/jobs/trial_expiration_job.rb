# frozen_string_literal: true

class TrialExpirationJob < ApplicationJob
  queue_as :default

  def perform
    # Find users whose trials have expired
    expired_users = User.where(
      'trial_expires_at < ? AND subscription_status = ?',
      Time.current,
      'trial'
    )

    expired_users.find_each do |user|
      # Update user status
      user.update!(subscription_status: 'expired')
      
      # Send expiration notification
      UserMailer.trial_expired(user).deliver_now
      
      Rails.logger.info "Trial expired for user #{user.id} (#{user.email})"
    end

    Rails.logger.info "Processed #{expired_users.count} expired trials"
  end
end