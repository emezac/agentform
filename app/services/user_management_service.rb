# frozen_string_literal: true

# Service for managing user operations in the admin interface
class UserManagementService < ApplicationService
  attribute :current_user
  attribute :filters, default: -> { {} }
  attribute :user_id
  attribute :user_params, default: -> { {} }
  attribute :suspension_reason
  attribute :transfer_data, default: false

  validates :current_user, presence: true
  validate :current_user_is_superadmin

  # List users with search, filters, and pagination
  def list_users
    return self unless valid?

    # Use optimized includes to avoid N+1 queries
    users = User.includes(
      :discount_code_usage, 
      forms: :form_responses,
      payment_transactions: []
    )
    
    # Apply search filter with optimized query
    if filters[:search].present?
      search_term = "%#{filters[:search].strip}%"
      users = users.where(
        'email ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ?',
        search_term, search_term, search_term
      )
    end
    
    # Apply role filter
    if filters[:role].present? && %w[user admin superadmin].include?(filters[:role])
      users = users.where(role: filters[:role])
    end
    
    # Apply subscription tier filter
    if filters[:tier].present? && %w[basic premium].include?(filters[:tier])
      users = users.where(subscription_tier: filters[:tier])
    end
    
    # Apply status filter
    case filters[:status]
    when 'active'
      users = users.where(suspended_at: nil)
    when 'suspended'
      users = users.where.not(suspended_at: nil)
    end
    
    # Apply date range filter
    if filters[:created_after].present?
      users = users.where('created_at >= ?', filters[:created_after])
    end
    
    if filters[:created_before].present?
      users = users.where('created_at <= ?', filters[:created_before])
    end
    
    # Order by creation date (newest first) by default
    users = users.order(created_at: :desc)
    
    # Apply pagination with optimized count query
    page = filters[:page] || 1
    per_page = filters[:per_page] || 25
    
    # Use limit/offset instead of Kaminari for better performance with large datasets
    total_count = users.count
    offset = (page.to_i - 1) * per_page.to_i
    paginated_users = users.limit(per_page).offset(offset)
    
    set_result({
      users: paginated_users,
      total_count: total_count,
      current_page: page.to_i,
      per_page: per_page.to_i,
      total_pages: (total_count.to_f / per_page.to_f).ceil
    })
    
    self
  end

  # Get detailed user information
  def get_user_details
    return self unless valid?
    
    unless user_id.present?
      errors.add(:user_id, 'is required')
      return self
    end

    user = find_record(User, user_id, :user)
    return self unless user

    subscription_details = get_subscription_details(user)
    usage_stats = get_usage_stats(user)
    recent_activity = get_recent_activity(user)
    discount_info = get_discount_info(user)

    set_result({
      user: user,
      subscription_details: subscription_details,
      usage_stats: usage_stats,
      recent_activity: recent_activity,
      discount_info: discount_info
    })

    self
  end

  # Create a new user
  def create_user
    return self unless valid?
    
    unless user_params.present?
      errors.add(:user_params, 'are required')
      return self
    end

    # Generate temporary password
    temp_password = SecureRandom.hex(8)
    
    user_attributes = user_params.merge(
      password: temp_password,
      password_confirmation: temp_password
    )
    
    user = User.new(user_attributes)
    
    if user.save
      # Send invitation email asynchronously
      UserInvitationJob.perform_later(user.id, temp_password)
      
      # Log the action
      Rails.logger.info "User #{user.email} created by admin #{current_user.email}"
      
      set_result({
        user: user,
        temporary_password: temp_password,
        message: 'User created successfully. Invitation email sent.'
      })
    else
      user.errors.each do |error|
        add_error(:user_creation, error.full_message)
      end
    end

    self
  end

  # Update user information
  def update_user
    return self unless valid?
    
    unless user_id.present?
      errors.add(:user_id, 'is required')
      return self
    end
    
    unless user_params.present?
      errors.add(:user_params, 'are required')
      return self
    end

    user = find_record(User, user_id, :user)
    return self unless user

    # Prevent self-demotion for superadmins
    if user == current_user && user_params[:role] && user_params[:role] != 'superadmin'
      add_error(:role, 'Cannot change your own role')
      return self
    end

    if user.update(user_params)
      # Log the action
      Rails.logger.info "User #{user.email} updated by admin #{current_user.email}"
      
      set_result({
        user: user,
        message: 'User updated successfully'
      })
    else
      user.errors.each do |error|
        add_error(:user_update, error.full_message)
      end
    end

    self
  end

  # Suspend a user
  def suspend_user
    return self unless valid?
    
    unless user_id.present?
      errors.add(:user_id, 'is required')
      return self
    end
    
    unless suspension_reason.present?
      errors.add(:suspension_reason, 'is required')
      return self
    end

    user = find_record(User, user_id, :user)
    return self unless user

    # Prevent self-suspension
    if user == current_user
      add_error(:suspension, 'Cannot suspend your own account')
      return self
    end

    # Prevent suspending other superadmins
    if user.superadmin?
      add_error(:suspension, 'Cannot suspend other superadmin accounts')
      return self
    end

    begin
      user.suspend!(suspension_reason)
      
      # Send suspension notification email
      UserSuspensionJob.perform_later(user.id, suspension_reason)
      
      # Log the action
      Rails.logger.info "User #{user.email} suspended by admin #{current_user.email}. Reason: #{suspension_reason}"
      
      set_result({
        user: user,
        message: 'User suspended successfully'
      })
    rescue StandardError => e
      add_error(:suspension, "Failed to suspend user: #{e.message}")
    end

    self
  end

  # Reactivate a suspended user
  def reactivate_user
    return self unless valid?
    
    unless user_id.present?
      errors.add(:user_id, 'is required')
      return self
    end

    user = find_record(User, user_id, :user)
    return self unless user

    unless user.suspended?
      add_error(:reactivation, 'User is not suspended')
      return self
    end

    begin
      user.reactivate!
      
      # Send reactivation notification email
      UserReactivationJob.perform_later(user.id)
      
      # Log the action
      Rails.logger.info "User #{user.email} reactivated by admin #{current_user.email}"
      
      set_result({
        user: user,
        message: 'User reactivated successfully'
      })
    rescue StandardError => e
      add_error(:reactivation, "Failed to reactivate user: #{e.message}")
    end

    self
  end

  # Delete a user
  def delete_user
    return self unless valid?
    
    unless user_id.present?
      errors.add(:user_id, 'is required')
      return self
    end

    user = find_record(User, user_id, :user)
    return self unless user

    # Prevent self-deletion
    if user == current_user
      add_error(:deletion, 'Cannot delete your own account')
      return self
    end

    # Prevent deleting other superadmins
    if user.superadmin?
      add_error(:deletion, 'Cannot delete other superadmin accounts')
      return self
    end

    begin
      user_email = user.email
      
      # Handle data transfer if requested
      if transfer_data && user.forms.exists?
        # Mark forms as archived but keep user association
        # In a real implementation, you might transfer to another user
        user.forms.update_all(status: 'archived')
      end
      
      if user.destroy
        # Log the action
        Rails.logger.info "User #{user_email} deleted by admin #{current_user.email}"
        
        set_result({
          message: 'User deleted successfully',
          deleted_user_email: user_email
        })
      else
        user.errors.each do |error|
          add_error(:deletion, error.full_message)
        end
      end
    rescue StandardError => e
      add_error(:deletion, "Failed to delete user: #{e.message}")
    end

    self
  end

  # Send password reset email to user
  def send_password_reset
    return self unless valid?
    
    unless user_id.present?
      errors.add(:user_id, 'is required')
      return self
    end

    user = find_record(User, user_id, :user)
    return self unless user

    begin
      # Generate password reset token using Devise
      token = user.send_reset_password_instructions
      
      # Log the action
      Rails.logger.info "Password reset sent to #{user.email} by admin #{current_user.email}"
      
      set_result({
        user: user,
        message: 'Password reset email sent successfully'
      })
    rescue StandardError => e
      add_error(:password_reset, "Failed to send password reset: #{e.message}")
    end

    self
  end

  # Get user statistics for dashboard
  def get_user_statistics
    return self unless valid?

    stats = {
      total_users: User.count,
      active_users: User.where(suspended_at: nil).count,
      suspended_users: User.where.not(suspended_at: nil).count,
      premium_users: User.where(subscription_tier: 'premium').count,
      admin_users: User.where(role: ['admin', 'superadmin']).count,
      users_this_month: User.where(created_at: 1.month.ago..Time.current).count,
      users_this_week: User.where(created_at: 1.week.ago..Time.current).count
    }

    set_result(stats)
    self
  end

  private

  def current_user_is_superadmin
    return unless current_user
    
    unless current_user.superadmin?
      errors.add(:authorization, 'Only superadmins can perform user management operations')
    end
  end

  def get_subscription_details(user)
    {
      tier: user.subscription_tier,
      status: user.subscription_status,
      expires_at: user.subscription_expires_at,
      stripe_customer_id: user.stripe_customer_id,
      subscription_id: user.respond_to?(:stripe_subscription_id) ? user.stripe_subscription_id : nil,
      payment_method: user.respond_to?(:payment_method_type) ? user.payment_method_type : nil,
      last_payment: user.payment_transactions.successful.order(:created_at).last,
      total_payments: user.payment_transactions.successful.sum(:amount)
    }
  end

  def get_usage_stats(user)
    {
      total_forms: user.forms.count,
      published_forms: user.forms.published.count,
      total_responses: user.form_responses.count,
      ai_credits_used: user.ai_credits_used,
      ai_credits_limit: user.monthly_ai_limit,
      last_form_created: user.forms.order(:created_at).last&.created_at,
      last_response_received: user.form_responses.order(:created_at).last&.created_at
    }
  end

  def get_recent_activity(user)
    activities = []
    
    # Recent forms
    user.forms.order(created_at: :desc).limit(5).each do |form|
      activities << {
        type: 'form_created',
        description: "Created form: #{form.name}",
        timestamp: form.created_at,
        resource: form
      }
    end
    
    # Recent responses
    user.form_responses.includes(:form).order(created_at: :desc).limit(5).each do |response|
      activities << {
        type: 'response_received',
        description: "Received response for: #{response.form.name}",
        timestamp: response.created_at,
        resource: response
      }
    end
    
    # Recent payments
    user.payment_transactions.successful.order(created_at: :desc).limit(3).each do |payment|
      activities << {
        type: 'payment_made',
        description: "Payment of $#{payment.amount_cents / 100.0}",
        timestamp: payment.created_at,
        resource: payment
      }
    end
    
    # Sort by timestamp and return latest 10
    activities.sort_by { |a| a[:timestamp] }.reverse.first(10)
  end

  def get_discount_info(user)
    {
      has_used_discount: user.discount_code_used?,
      discount_usage: user.discount_code_usage,
      eligible_for_discount: user.eligible_for_discount?
    }
  end
end