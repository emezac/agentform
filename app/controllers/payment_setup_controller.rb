# frozen_string_literal: true

class PaymentSetupController < ApplicationController
  before_action :authenticate_user!
  before_action :set_template, only: [:index]

  # GET /payment_setup
  def index
    skip_policy_scope
    authorize current_user, :update?
    
    @template = FormTemplate.find(params[:template_id]) if params[:template_id].present?
    @return_to = params[:return_to] || templates_path
    
    # Get current setup status
    @setup_status = current_user.payment_setup_status
    @required_features = @template&.required_features || []
    
    # Check what setup steps are needed
    @setup_requirements = PaymentSetupValidationService.call(
      user: current_user,
      required_features: @required_features
    )
    
    # Track analytics
    track_event('payment_setup_page_viewed', {
      template_id: @template&.id,
      required_features: @required_features,
      current_setup_status: @setup_status
    })
  end

  # POST /payment_setup/complete
  def complete
    authorize current_user, :update?
    
    @template = FormTemplate.find(params[:template_id]) if params[:template_id].present?
    @return_to = params[:return_to] || templates_path
    
    # Validate that setup is actually complete
    validation_result = PaymentSetupValidationService.call(
      user: current_user,
      required_features: @template&.required_features || []
    )
    
    if validation_result.success?
      # Track completion
      track_event('payment_setup_completed', {
        template_id: @template&.id,
        setup_duration: session[:payment_setup_started_at] ? Time.current - session[:payment_setup_started_at] : nil
      })
      
      # Clear setup session
      session.delete(:payment_setup_started_at)
      
      if @template
        # Redirect to template show page with success message
        redirect_to template_path(@template), 
                    notice: "Payment setup complete! You can now use this payment-enabled template."
      else
        # Redirect to return URL
        redirect_to @return_to, 
                    notice: "Payment setup complete!"
      end
    else
      # Setup not complete, show requirements
      @setup_status = current_user.payment_setup_status
      @setup_requirements = validation_result
      
      flash.now[:alert] = "Payment setup is not yet complete. Please finish the required steps."
      render :index
    end
  end

  private

  def set_template
    @template = FormTemplate.find(params[:template_id]) if params[:template_id].present?
  end

  def track_event(event_name, properties = {})
    # Integration with analytics system
    if defined?(Analytics) && Analytics.respond_to?(:track)
      Analytics.track(
        user_id: current_user.id,
        event: event_name,
        properties: properties.merge(
          timestamp: Time.current.iso8601,
          user_role: current_user.role,
          user_subscription: current_user.subscription_tier
        )
      )
    end

    # Log for development
    Rails.logger.info "Analytics: #{event_name} - #{properties}" if Rails.env.development?
  end
end