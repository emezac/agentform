class TemplatePaymentAnalysisJob < ApplicationJob
  # High priority for user-initiated actions
  sidekiq_options queue: 'ai_processing', retry: 5, backtrace: true, dead: false, retry_in: proc { |count|
    case count
    when 0..2
      10 * (count + 1) # 10s, 20s, 30s
    when 3..4
      60 * (count - 2) # 60s, 120s
    else
      300 # 5 minutes for final attempt
    end
  }
  
  def perform(template_id, user_id = nil, options = {})
    @template = FormTemplate.find(template_id)
    @user = User.find(user_id) if user_id
    @options = options.with_indifferent_access
    
    Rails.logger.info "Starting template payment analysis for template #{template_id}"
    
    begin
      # Perform complex template analysis
      analysis_result = analyze_template_payment_requirements
      
      # Update template metadata
      update_template_metadata(analysis_result)
      
      # Notify completion via Turbo Streams if user is present
      broadcast_completion_notification(analysis_result) if @user
      
      Rails.logger.info "Completed template payment analysis for template #{template_id}"
      
      analysis_result
    rescue StandardError => e
      Rails.logger.error "Template payment analysis failed for template #{template_id}: #{e.message}"
      
      # Broadcast error notification if user is present
      broadcast_error_notification(e) if @user
      
      raise e
    end
  end
  
  private
  
  def analyze_template_payment_requirements
    # Use TemplateAnalysisService for complex analysis
    service = TemplateAnalysisService.new
    result = service.analyze_payment_requirements(@template)
    
    # Add additional processing for complex templates
    if @template.questions_config.count > 50
      result = perform_deep_analysis(result)
    end
    
    result
  end
  
  def perform_deep_analysis(initial_result)
    # Perform more detailed analysis for large templates
    payment_questions = @template.questions_config.select do |q|
      PaymentRequirementDetector::PAYMENT_QUESTION_TYPES.include?(q['question_type'])
    end
    
    # Analyze payment flow complexity
    flow_complexity = calculate_payment_flow_complexity(payment_questions)
    
    # Determine integration requirements
    integration_requirements = determine_integration_requirements(payment_questions)
    
    initial_result.merge(
      flow_complexity: flow_complexity,
      integration_requirements: integration_requirements,
      deep_analysis_performed: true
    )
  end
  
  def calculate_payment_flow_complexity(payment_questions)
    complexity_score = 0
    
    payment_questions.each do |question|
      case question['question_type']
      when 'payment'
        complexity_score += 3
      when 'subscription'
        complexity_score += 5
      when 'donation'
        complexity_score += 2
      end
      
      # Add complexity for conditional logic
      complexity_score += 1 if question['conditional_logic'].present?
    end
    
    case complexity_score
    when 0..5
      'simple'
    when 6..15
      'moderate'
    else
      'complex'
    end
  end
  
  def determine_integration_requirements(payment_questions)
    requirements = []
    
    if payment_questions.any? { |q| q['question_type'] == 'subscription' }
      requirements << 'recurring_payments'
    end
    
    if payment_questions.any? { |q| q['question_type'] == 'donation' }
      requirements << 'donation_processing'
    end
    
    if payment_questions.count > 1
      requirements << 'multi_payment_handling'
    end
    
    requirements
  end
  
  def update_template_metadata(analysis_result)
    @template.update!(
      payment_enabled: analysis_result[:has_payment_questions],
      required_features: analysis_result[:required_features],
      setup_complexity: analysis_result[:setup_complexity],
      metadata: (@template.metadata || {}).merge(
        payment_analysis: analysis_result,
        last_analyzed_at: Time.current
      )
    )
  end
  
  def broadcast_completion_notification(analysis_result)
    return unless @user
    
    Turbo::StreamsChannel.broadcast_update_to(
      "user_#{@user.id}",
      target: "template_analysis_status_#{@template.id}",
      partial: "shared/template_analysis_complete",
      locals: { 
        template: @template, 
        analysis_result: analysis_result,
        user: @user
      }
    )
  end
  
  def broadcast_error_notification(error)
    return unless @user
    
    Turbo::StreamsChannel.broadcast_update_to(
      "user_#{@user.id}",
      target: "template_analysis_status_#{@template.id}",
      partial: "shared/template_analysis_error",
      locals: { 
        template: @template, 
        error: error.message,
        user: @user
      }
    )
  end
end