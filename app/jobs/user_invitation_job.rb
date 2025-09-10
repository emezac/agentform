# frozen_string_literal: true

# Background job for sending user invitation emails
class UserInvitationJob < ApplicationJob
  queue_as :integrations
  
  # Retry with exponential backoff for email delivery failures
  retry_on Net::SMTPError, wait: :exponentially_longer, attempts: 5
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(user_id, temporary_password)
    user = User.find(user_id)
    
    Rails.logger.info "Sending invitation email to user #{user.email}"
    
    begin
      UserMailer.admin_invitation(user, temporary_password).deliver_now
      
      # Log successful email delivery
      AuditLog.create!(
        user: user,
        event_type: 'user_invitation_sent',
        details: {
          user_id: user.id,
          email: user.email,
          sent_at: Time.current
        },
        ip_address: 'system'
      )
      
      Rails.logger.info "Invitation email sent successfully to #{user.email}"
      
    rescue StandardError => e
      Rails.logger.error "Failed to send invitation email to #{user.email}: #{e.message}"
      
      # Log email delivery failure
      AuditLog.create!(
        user: user,
        event_type: 'user_invitation_failed',
        details: {
          user_id: user.id,
          email: user.email,
          error: e.message,
          failed_at: Time.current
        },
        ip_address: 'system'
      )
      
      raise e
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "User with ID #{user_id} not found for invitation email"
  end
end