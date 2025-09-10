class PaymentSetupValidationJob < ApplicationJob
  # High priority for user setup changes
  sidekiq_options queue: 'critical', retry: 3, backtrace: true, dead: false, retry_in: proc { |count|
    case count
    when 0
      5 # 5 seconds for first retry
    when 1
      30 # 30 seconds for second retry
    else
      120 # 2 minutes for final retry
    end
  }
  
  def perform(user_id, trigger_event = 'setup_change', options = {})
    @user = User.find(user_id)
    @trigger_event = trigger_event
    @options = options.with_indifferent_access
    
    Rails.logger.info "Starting payment setup validation for user #{user_id}, trigger: #{trigger_event}"
    
    begin
      # Validate current user setup
      validation_result = validate_user_payment_setup
      
      # Update affected forms
      updated_forms = update_form_statuses(validation_result)
      
      # Broadcast real-time updates
      broadcast_setup_status_updates(validation_result, updated_forms)
      
      Rails.logger.info "Completed payment setup validation for user #{user_id}, updated #{updated_forms.count} forms"
      
      {
        validation_result: validation_result,
        updated_forms_count: updated_forms.count,
        trigger_event: @trigger_event
      }
    rescue StandardError => e
      Rails.logger.error "Payment setup validation failed for user #{user_id}: #{e.message}"
      
      # Broadcast error notification
      broadcast_validation_error(e)
      
      raise e
    end
  end
  
  private
  
  def validate_user_payment_setup
    service = PaymentSetupValidationService.new
    
    # Get all required features from user's forms with payment questions
    required_features = determine_user_required_features
    
    # Validate user setup against requirements
    validation_result = service.validate_user_requirements(@user, required_features)
    
    # Add setup completion percentage
    validation_result[:setup_completion_percentage] = calculate_setup_completion_percentage(validation_result)
    
    validation_result
  end
  
  def determine_user_required_features
    payment_forms = @user.forms.joins(:template)
                         .where(form_templates: { payment_enabled: true })
    
    required_features = Set.new
    
    payment_forms.each do |form|
      template_features = form.template.required_features || []
      required_features.merge(template_features)
    end
    
    required_features.to_a
  end
  
  def calculate_setup_completion_percentage(validation_result)
    return 100 if validation_result[:valid]
    
    total_requirements = validation_result[:missing_requirements].count + 
                        (validation_result[:valid] ? 1 : 0)
    completed_requirements = validation_result[:valid] ? 1 : 0
    
    return 0 if total_requirements == 0
    
    (completed_requirements.to_f / total_requirements * 100).round
  end
  
  def update_form_statuses(validation_result)
    updated_forms = []
    
    # Find all forms with payment questions
    payment_forms = @user.forms.joins(:template)
                         .where(form_templates: { payment_enabled: true })
    
    payment_forms.each do |form|
      old_status = form.payment_setup_complete?
      
      # Update form's cached payment setup status
      form.update_column(:payment_setup_complete, validation_result[:valid])
      
      # Track forms that changed status
      if old_status != validation_result[:valid]
        updated_forms << form
        
        # Update form metadata
        form.update!(
          metadata: (form.metadata || {}).merge(
            payment_validation: {
              last_validated_at: Time.current,
              validation_result: validation_result,
              trigger_event: @trigger_event
            }
          )
        )
      end
    end
    
    updated_forms
  end
  
  def broadcast_setup_status_updates(validation_result, updated_forms)
    # Broadcast general setup status update
    Turbo::StreamsChannel.broadcast_update_to(
      "user_#{@user.id}",
      target: "payment_setup_status",
      partial: "shared/payment_setup_status",
      locals: { 
        user: @user, 
        validation_result: validation_result 
      }
    )
    
    # Broadcast updates for each affected form
    updated_forms.each do |form|
      broadcast_form_status_update(form, validation_result)
    end
    
    # Broadcast notification if setup is now complete
    if validation_result[:valid] && @trigger_event == 'setup_completion'
      broadcast_setup_completion_notification(validation_result)
    end
  end
  
  def broadcast_form_status_update(form, validation_result)
    Turbo::StreamsChannel.broadcast_update_to(
      "form_#{form.id}",
      target: "form_payment_status_#{form.id}",
      partial: "forms/payment_status_indicator",
      locals: { 
        form: form, 
        validation_result: validation_result 
      }
    )
    
    # Update form editor if form is being edited
    Turbo::StreamsChannel.broadcast_update_to(
      "form_editor_#{form.id}",
      target: "payment_notification_bar",
      partial: "forms/payment_notification_bar",
      locals: { 
        form: form, 
        validation_result: validation_result 
      }
    )
  end
  
  def broadcast_setup_completion_notification(validation_result)
    Turbo::StreamsChannel.broadcast_update_to(
      "user_#{@user.id}",
      target: "notifications",
      partial: "shared/setup_completion_notification",
      locals: { 
        user: @user, 
        validation_result: validation_result 
      }
    )
  end
  
  def broadcast_validation_error(error)
    Turbo::StreamsChannel.broadcast_update_to(
      "user_#{@user.id}",
      target: "payment_setup_status",
      partial: "shared/payment_validation_error",
      locals: { 
        user: @user, 
        error: error.message 
      }
    )
  end
end