# frozen_string_literal: true

# Background job for sending user suspension notification emails
class UserSuspensionJob < ApplicationJob
  queue_as :integrations
  
  # Retry with exponential backoff for email delivery failures
  retry_on Net::SMTPError, wait: :exponentially_longer, attempts: 5
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  def perform(user_id, suspension_reason)
    user = User.find(user_id)
    
    Rails.logger.info "Sending suspension notification to user #{user.email}"
    
    begin
      UserMailer.account_suspended(user, suspension_reason).deliver_now
      
      # Log successful email delivery
      AuditLog.create!(
        user: user,
        event_type: 'user_suspension_notification_sent',
        details: {
          user_id: user.id,
          email: user.email,
          suspension_reason: suspension_reason,
          sent_at: Time.current
        },
        ip_address: 'system'
      )
      
      Rails.logger.info "Suspension notification sent successfully to #{user.email}"
      
    rescue StandardError => e
      Rails.logger.error "Failed to send suspension notification to #{user.email}: #{e.message}"
      
      # Log email delivery failure
      AuditLog.create!(
        user: user,
        event_type: 'user_suspension_notification_failed',
        details: {
          user_id: user.id,
          email: user.email,
          suspension_reason: suspension_reason,
          error: e.message,
          failed_at: Time.current
        },
        ip_address: 'system'
      )
      
      raise e
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "User with ID #{user_id} not found for suspension notification"
  end
end