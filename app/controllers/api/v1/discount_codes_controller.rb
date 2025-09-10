class Api::V1::DiscountCodesController < ApplicationController
  before_action :authenticate_user!
  
  # Skip CSRF protection for API endpoints
  skip_before_action :verify_authenticity_token
  
  # Skip Pundit callbacks for API endpoints
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  # POST /api/v1/discount_codes/validate
  def validate
    service = DiscountCodeService.new(
      user: current_user,
      code: params[:code]
    )

    result = service.validate_code

    if service.success?
      discount_code = service.result[:discount_code]
      
      # Calculate discount for the requested plan
      original_amount = calculate_plan_amount(params[:billing_cycle])
      discount_calculation = service.calculate_discount(discount_code, original_amount)

      render json: {
        valid: true,
        discount_code: {
          code: discount_code.code,
          discount_percentage: discount_code.discount_percentage
        },
        pricing: {
          original_amount: original_amount,
          discount_amount: discount_calculation[:discount_amount],
          final_amount: discount_calculation[:final_amount],
          currency: 'USD'
        }
      }
    else
      render json: {
        valid: false,
        error: service.errors.full_messages.first || 'Invalid discount code'
      }, status: :unprocessable_entity
    end
  end

  private

  def calculate_plan_amount(billing_cycle)
    plans = SubscriptionManagementService.plans
    case billing_cycle
    when 'yearly'
      plans['premium'][:price_yearly]
    else
      plans['premium'][:price_monthly]
    end
  end
end