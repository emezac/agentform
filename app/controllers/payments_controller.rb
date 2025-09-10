class PaymentsController < ApplicationController
  before_action :set_form_and_response
  before_action :validate_payment_enabled

  # POST /f/:share_token/payments
  def create
    result = StripePaymentService.call(
      user: @form.user,
      form: @form,
      form_response: @form_response,
      payment_data: payment_params
    )

    if result.success?
      render json: {
        success: true,
        client_secret: result.data[:client_secret],
        payment_intent_id: result.data[:payment_intent].id,
        transaction_id: result.data[:transaction].id
      }
    else
      render json: {
        success: false,
        error: result.error_message
      }, status: :unprocessable_entity
    end
  end

  # POST /f/:share_token/payments/:payment_intent_id/confirm
  def confirm
    transaction = PaymentTransaction.find_by(
      stripe_payment_intent_id: params[:payment_intent_id],
      form: @form
    )

    unless transaction
      render json: { success: false, error: 'Payment not found' }, status: :not_found
      return
    end

    # Sync with Stripe to get latest status
    if transaction.sync_with_stripe!
      if transaction.successful?
        # Mark form response as paid
        @form_response.update!(
          payment_status: 'paid',
          payment_amount: transaction.amount,
          payment_currency: transaction.currency,
          payment_transaction_id: transaction.id
        )

        render json: {
          success: true,
          status: 'succeeded',
          transaction_id: transaction.id,
          redirect_url: thank_you_form_path(@form.share_token)
        }
      else
        render json: {
          success: false,
          status: transaction.status,
          error: transaction.failure_reason || 'Payment failed'
        }
      end
    else
      render json: {
        success: false,
        error: 'Unable to verify payment status'
      }, status: :unprocessable_entity
    end
  end

  # GET /f/:share_token/payments/config
  def config
    unless @form.user.stripe_configured?
      render json: { 
        success: false, 
        error: 'Payment processing not configured for this form' 
      }, status: :unprocessable_entity
      return
    end

    render json: {
      success: true,
      publishable_key: @form.user.stripe_publishable_key,
      currency: 'USD', # Default currency, could be configurable per form
      test_mode: @form.user.stripe_publishable_key.start_with?('pk_test_')
    }
  end

  private

  def set_form_and_response
    @form = Form.find_by!(share_token: params[:share_token])
    @form_response = @form.form_responses.find(params[:form_response_id]) if params[:form_response_id]
    
    unless @form_response
      render json: { success: false, error: 'Form response not found' }, status: :not_found
    end
  end

  def validate_payment_enabled
    unless @form.user.can_accept_payments?
      render json: { 
        success: false, 
        error: 'Payment processing not available for this form' 
      }, status: :forbidden
    end
  end

  def payment_params
    params.require(:payment).permit(:amount, :currency, :payment_method, :email)
  end
end