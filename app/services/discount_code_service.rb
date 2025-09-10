# frozen_string_literal: true

# Service for handling discount code validation, application, and usage tracking
class DiscountCodeService < ApplicationService
  attribute :user
  attribute :code, :string
  attribute :original_amount, :integer
  attribute :subscription_id, :string

  # Validate a discount code for a user
  def validate_code
    validate_required_attributes(:user, :code)
    return self if failure?

    discount_code = find_discount_code
    return self if failure?

    validate_code_availability(discount_code)
    return self if failure?

    validate_user_eligibility
    return self if failure?

    set_result(discount_code: discount_code)
    self
  end

  # Calculate discount for display purposes (doesn't validate user eligibility)
  def calculate_discount(discount_code, amount)
    unless discount_code.is_a?(DiscountCode)
      return {
        original_amount: amount,
        discount_amount: 0,
        final_amount: amount,
        discount_percentage: 0
      }
    end

    unless amount.is_a?(Integer) && amount > 0
      return {
        original_amount: amount,
        discount_amount: 0,
        final_amount: amount,
        discount_percentage: 0
      }
    end

    discount_amount = calculate_discount_amount(discount_code, amount)
    final_amount = [amount - discount_amount, 0].max

    {
      original_amount: amount,
      discount_amount: discount_amount,
      final_amount: final_amount,
      discount_percentage: discount_code.discount_percentage
    }
  end

  # Apply discount calculation to an amount
  def apply_discount(discount_code, amount)
    validate_required_attributes(:user)
    return self if failure?

    unless discount_code.is_a?(DiscountCode)
      add_error(:discount_code, 'must be a DiscountCode instance')
      return self
    end

    unless amount.is_a?(Integer) && amount > 0
      add_error(:original_amount, 'must be a positive integer (amount in cents)')
      return self
    end

    discount_amount = calculate_discount_amount(discount_code, amount)
    final_amount = [amount - discount_amount, 0].max

    discount_details = {
      original_amount: amount,
      discount_amount: discount_amount,
      final_amount: final_amount,
      discount_percentage: discount_code.discount_percentage,
      savings_percentage: amount > 0 ? (discount_amount.to_f / amount * 100).round(1) : 0
    }

    set_result(discount_details)
    self
  end

  # Record usage of a discount code after successful subscription
  def record_usage(discount_code, subscription_details)
    validate_required_attributes(:user)
    return self if failure?

    unless discount_code.is_a?(DiscountCode)
      add_error(:discount_code, 'must be a DiscountCode instance')
      return self
    end

    validate_subscription_details(subscription_details)
    return self if failure?

    # Double-check user eligibility before recording
    validate_user_eligibility
    return self if failure?

    usage_record = nil
    
    safe_db_operation do
      # Use database transaction with retry logic for concurrent access
      ActiveRecord::Base.transaction do
        # Re-check discount code availability within transaction
        discount_code.reload
        unless discount_code.available?
          if discount_code.usage_limit_reached?
            add_error(:discount_code, 'This discount code has reached its usage limit')
          elsif !discount_code.active?
            add_error(:discount_code, 'This discount code is no longer active')
          elsif discount_code.expired?
            add_error(:discount_code, 'This discount code has expired')
          end
          raise ActiveRecord::Rollback
        end

        # Re-check user eligibility within transaction
        user.reload
        unless user.eligible_for_discount?
          add_error(:user, 'You are no longer eligible for discount codes')
          raise ActiveRecord::Rollback
        end

        usage_record = create_usage_record(discount_code, subscription_details)
        update_discount_code_usage(discount_code)
        mark_user_as_used_discount
        deactivate_code_if_exhausted(discount_code)
      end
    end

    return self if failure?

    set_result(usage_record: usage_record)
    self
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => e
    # Handle concurrent access conflicts
    if e.message.include?('duplicate key') || e.message.include?('unique constraint')
      add_error(:concurrency, 'This discount code was just used by another user. Please try a different code.')
    else
      add_error(:database, "Database error: #{e.message}")
    end
    self
  end

  # Check if a discount code is valid and available
  def check_availability(code_string)
    self.code = code_string
    validate_required_attributes(:code)
    return self if failure?

    discount_code = find_discount_code
    return self if failure?

    availability_status = {
      code: discount_code.code,
      valid: true,
      active: discount_code.active?,
      expired: discount_code.expired?,
      usage_limit_reached: discount_code.usage_limit_reached?,
      available: discount_code.available?,
      discount_percentage: discount_code.discount_percentage,
      remaining_uses: discount_code.remaining_uses,
      expires_at: discount_code.expires_at
    }

    set_result(availability_status)
    self
  end

  # Check user eligibility for discount codes with detailed feedback
  def check_user_eligibility
    validate_required_attributes(:user)
    return self if failure?

    eligibility_status = {
      eligible: user.eligible_for_discount?,
      reasons: []
    }

    unless user.eligible_for_discount?
      if user.discount_code_used?
        eligibility_status[:reasons] << 'User has already used a discount code'
      end
      
      if user.suspended?
        eligibility_status[:reasons] << 'User account is suspended'
      end
      
      if user.subscription_tier == 'premium'
        eligibility_status[:reasons] << 'User already has a premium subscription'
      end
    end

    set_result(eligibility_status)
    self
  end

  # Get usage statistics for a discount code
  def get_usage_statistics(discount_code)
    unless discount_code.is_a?(DiscountCode)
      add_error(:discount_code, 'must be a DiscountCode instance')
      return self
    end

    stats = {
      code: discount_code.code,
      total_uses: discount_code.current_usage_count,
      max_uses: discount_code.max_usage_count,
      remaining_uses: discount_code.remaining_uses,
      usage_percentage: discount_code.usage_percentage,
      revenue_impact: discount_code.revenue_impact,
      active: discount_code.active?,
      expired: discount_code.expired?,
      created_at: discount_code.created_at,
      expires_at: discount_code.expires_at,
      recent_usages: discount_code.discount_code_usages.recent.limit(10).includes(:user)
    }

    set_result(stats)
    self
  end

  # Deactivate expired or exhausted codes (for background job)
  def deactivate_expired_codes
    deactivated_count = 0

    safe_db_operation do
      # Deactivate expired codes
      expired_count = DiscountCode.active.expired.update_all(active: false, updated_at: Time.current)
      deactivated_count += expired_count

      # Deactivate exhausted codes
      exhausted_codes = DiscountCode.active.where.not(max_usage_count: nil)
                                   .where('current_usage_count >= max_usage_count')
      exhausted_count = exhausted_codes.update_all(active: false, updated_at: Time.current)
      deactivated_count += exhausted_count
    end

    return self if failure?

    set_result(deactivated_count: deactivated_count)
    self
  end

  private

  def find_discount_code
    normalized_code = code&.upcase&.strip
    
    if normalized_code.blank?
      add_error(:code, 'cannot be blank')
      return nil
    end

    begin
      discount_code = DiscountCode.find_by(code: normalized_code)
    rescue StandardError => e
      add_error(:database, "Database error: #{e.message}")
      return nil
    end
    
    unless discount_code
      add_error(:code, 'Invalid discount code')
      return nil
    end

    discount_code
  end

  def validate_code_availability(discount_code)
    unless discount_code.active?
      add_error(:code, 'This discount code is no longer active')
      return false
    end

    if discount_code.expired?
      add_error(:code, 'This discount code has expired')
      return false
    end

    if discount_code.usage_limit_reached?
      add_error(:code, 'This discount code has reached its usage limit')
      return false
    end

    true
  end

  def validate_user_eligibility
    unless user.eligible_for_discount?
      if user.discount_code_used?
        add_error(:user, 'You have already used a discount code. Each account can only use one discount code.')
      elsif user.suspended?
        add_error(:user, 'Your account is suspended and cannot use discount codes. Please contact support.')
      elsif user.subscription_tier == 'premium'
        add_error(:user, 'Premium users cannot use discount codes on additional subscriptions.')
      else
        add_error(:user, 'You are not eligible for discount codes at this time.')
      end
      return false
    end

    true
  end

  def calculate_discount_amount(discount_code, amount)
    (amount * discount_code.discount_percentage / 100.0).round
  end

  def validate_subscription_details(details)
    required_fields = [:subscription_id, :original_amount, :discount_amount, :final_amount]
    
    required_fields.each do |field|
      unless details.key?(field) && details[field].present?
        add_error(:subscription_details, "#{field} is required")
      end
    end

    return if failure?

    # Validate amounts are positive integers
    [:original_amount, :discount_amount, :final_amount].each do |field|
      amount = details[field]
      unless amount.is_a?(Integer) && amount >= 0
        add_error(:subscription_details, "#{field} must be a non-negative integer")
      end
    end

    return if failure?

    # Validate calculation is correct
    expected_final = details[:original_amount] - details[:discount_amount]
    unless details[:final_amount] == expected_final
      add_error(:subscription_details, 'Final amount calculation is incorrect')
    end
  end

  def create_usage_record(discount_code, subscription_details)
    DiscountCodeUsage.create!(
      discount_code: discount_code,
      user: user,
      subscription_id: subscription_details[:subscription_id],
      original_amount: subscription_details[:original_amount],
      discount_amount: subscription_details[:discount_amount],
      final_amount: subscription_details[:final_amount],
      used_at: Time.current
    )
  end

  def update_discount_code_usage(discount_code)
    discount_code.increment!(:current_usage_count)
  end

  def mark_user_as_used_discount
    user.mark_discount_code_as_used!
  end

  def deactivate_code_if_exhausted(discount_code)
    if discount_code.reload.usage_limit_reached?
      discount_code.update!(active: false)
      Rails.logger.info "Discount code #{discount_code.code} deactivated due to usage limit reached"
    end
  end
end