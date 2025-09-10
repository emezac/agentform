# frozen_string_literal: true

class ResponsesController < ApplicationController
  skip_before_action :authenticate_user!
  skip_after_action :verify_authorized, unless: :skip_authorization?
  skip_after_action :verify_policy_scoped, unless: :skip_authorization?
  before_action :set_form, only: [:show, :answer, :thank_you, :preview, :save_draft, :abandon, :resume]
  before_action :set_or_create_response, only: [:show, :answer]
  before_action :validate_form_access, only: [:show, :answer]
  before_action :track_form_view, only: [:show]
  
  # Public Actions
  
  # GET /f/:share_token - Show form to respondent
  def show
    Rails.logger.info "=== SHOW ACTION START ==="
    Rails.logger.info "Form state at start:"
    Rails.logger.info "Form present: #{@form.present?}"
    Rails.logger.info "Form share_token: #{@form&.share_token}"
    Rails.logger.info "Form ID: #{@form&.id}"
    Rails.logger.info "Form name: #{@form&.name}"
    
    @current_question = find_current_question
    @progress_percentage = @form_response.progress_percentage
    @total_questions = @form.form_questions.count
    
    Rails.logger.info "After finding current question:"
    Rails.logger.info "Current question: #{@current_question&.title}"
    Rails.logger.info "Form still present: #{@form.present?}"
    Rails.logger.info "Form share_token: #{@form&.share_token}"
    
    # Handle form completion
    if @form_response.completed?
      redirect_path = thank_you_form_path(@form.share_token)
      Rails.logger.info "Form completed, redirecting to: #{redirect_path}"
      redirect_to redirect_path
      return
    end
    
    # Handle no more questions (auto-complete)
    unless @current_question
      Rails.logger.info "No current question found, completing form"
      complete_form_response!
      redirect_path = thank_you_form_path(@form.share_token)
      Rails.logger.info "Auto-complete redirecting to: #{redirect_path}"
      redirect_to redirect_path
      return
    end
    
    prepare_question_data
    
    Rails.logger.info "Before rendering template:"
    Rails.logger.info "Form share_token for template: #{@form&.share_token}"
    
    respond_to do |format|
      format.html { render_form_layout }
      format.json { render_json_response }
    end
  end
  
  # POST /f/:share_token/answer - Submit answer to current question
  def answer
    Rails.logger.info "=== ANSWER ACTION START ==="
    @current_question = find_question_by_id(params[:question_id])

    unless @current_question
      return render_error("Question not found", :not_found)
    end

    # 1. Procesa y guarda la respuesta actual del usuario
    result = process_answer_submission
    unless result[:success]
      return respond_to_answer_error(result)
    end

    # 2. Actualiza la actividad de la respuesta
    @form_response.touch(:last_activity_at)
    @form = @form_response.form # Aseguramos que @form esté cargado

    # 3. IMPORTANTE: Después de guardar la respuesta, necesitamos verificar
    #    si esta respuesta afecta la visibilidad de otras preguntas.
    #    Para esto, invalidamos las respuestas de preguntas futuras que
    #    podrían haber sido afectadas por cambios en la lógica condicional.
    invalidate_conditional_responses_if_needed

    # 4. Encuentra la próxima pregunta visible con la nueva lógica
    next_question = find_current_question

    # 5. Verifica si el formulario está listo para ser completado
    if next_question.nil? && @form_response.can_be_completed?
      complete_form_response!
      
      redirect_path = thank_you_form_path(@form.share_token)
      Rails.logger.info "Form completion detected, redirecting to: #{redirect_path}"
      
      return respond_to do |format|
        format.json { render json: { success: true, completed: true, redirect_url: redirect_path } }
        format.html { redirect_to redirect_path }
      end
    end

    # 6. Si no se ha completado, prepara la respuesta para la siguiente pregunta
    Rails.logger.info "=== NEXT QUESTION RESPONSE ==="
    Rails.logger.info "Next question: #{next_question&.title}"

    respond_to do |format|
      format.json do
        render json: {
          success: true,
          next_question: next_question ? serialize_question(next_question) : nil,
          progress: @form_response.progress_percentage,
          completed: next_question.nil?
        }
      end
      format.html { redirect_to public_form_path(@form.share_token) }
    end
  end
  
  # GET /f/:share_token/thank-you - Thank you page after completion
  def thank_you
    @completion_data = session[:completion_data] || {}
    @form_response = find_completed_response
    
    # Clear session data
    clear_response_session
    
    respond_to do |format|
      format.html { render_thank_you_page }
      format.json { render_completion_json }
    end
  end
  
  # GET /f/:share_token/preview - Preview form (for form creators)
  def preview
    @preview_mode = true
    @current_question = @form.form_questions.first
    @progress_percentage = 0
    @total_questions = @form.form_questions.count
    
    prepare_question_data
    render :show
  end
  
  # POST /f/:share_token/save_draft - Save partial response as draft
  def save_draft
    @form_response = find_or_create_response
    
    result = save_draft_data
    
    respond_to do |format|
      format.json { render json: result }
    end
  end
  
  # POST /f/:share_token/abandon - Mark response as abandoned
  def abandon
    @form_response = find_response_by_session
    
    if @form_response
      abandonment_reason = params[:reason] || 'user_abandoned'
      @form_response.mark_abandoned!(abandonment_reason)
      
      # Track abandonment analytics
      track_form_abandonment(abandonment_reason)
    end
    
    head :ok
  end
  
  # GET /f/:share_token/resume/:session_id - Resume abandoned response
  def resume
    @form_response = find_response_by_session(params[:session_id])
    
    unless @form_response&.paused?
      redirect_to public_form_path(@form.share_token)
      return
    end
    
    @form_response.resume!
    session[:form_response_id] = @form_response.id
    
    redirect_to public_form_path(@form.share_token)
  end
  
  def debug_conditional_logic
    return unless Rails.env.development?
    
    if @current_question&.has_conditional_logic?
      puts "\n" + "="*50
      puts "DEBUGGING CURRENT QUESTION: #{@current_question.title}"
      @current_question.debug_conditional_setup(@form_response)
      puts "="*50 + "\n"
    end
    
    # Debug all questions in the form
    @form.form_questions.where(conditional_enabled: true).each do |question|
      question.debug_conditional_setup(@form_response)
    end
  end

  private

  def invalidate_conditional_responses_if_needed
    # Encuentra todas las preguntas que dependen de la pregunta actual
    dependent_questions = @form.form_questions.where(
      "conditional_logic -> 'rules' @> ?", 
      [{ question_id: @current_question.id }].to_json
    )
    
    return if dependent_questions.empty?
    
    Rails.logger.info "Found #{dependent_questions.count} questions that depend on #{@current_question.title}"
    
    dependent_questions.each do |dependent_question|
      Rails.logger.info "Checking if we need to invalidate responses for: #{dependent_question.title}"
      
      # Verifica si esta pregunta dependiente ya fue respondida
      existing_response = @form_response.question_responses.find_by(form_question: dependent_question)
      
      if existing_response
        # Verifica si la pregunta dependiente debe seguir siendo visible
        should_show = dependent_question.should_show_for_response?(@form_response)
        
        Rails.logger.info "Dependent question '#{dependent_question.title}' should show: #{should_show}"
        
        unless should_show
          # Si la pregunta ya no debe mostrarse, elimina su respuesta
          Rails.logger.info "Removing response for question that should no longer be visible: #{dependent_question.title}"
          existing_response.destroy!
          
          # También invalida respuestas de preguntas que dependan de esta
          invalidate_recursive_dependencies(dependent_question)
        end
      end
    end
  end

  # Método recursivo para invalidar dependencias en cascada
  def invalidate_recursive_dependencies(question)
    # Encuentra preguntas que dependen de la pregunta dada
    dependent_questions = @form.form_questions.where(
      "conditional_logic -> 'rules' @> ?", 
      [{ question_id: question.id }].to_json
    )
    
    dependent_questions.each do |dependent_question|
      existing_response = @form_response.question_responses.find_by(form_question: dependent_question)
      
      if existing_response
        Rails.logger.info "Recursively removing response for: #{dependent_question.title}"
        existing_response.destroy!
        
        # Continúa la recursión
        invalidate_recursive_dependencies(dependent_question)
      end
    end
  end
  
  def respond_to_answer_error(result)
    respond_to do |format|
      format.json do
        render json: { 
          success: false, 
          errors: result[:errors],
          question_id: @current_question.id
        }, status: :unprocessable_entity
      end
      format.html do
        flash[:error] = result[:errors].join(', ')
        redirect_back(fallback_location: public_form_path(@form.share_token))
      end
    end
  end
  
  def set_form
    Rails.logger.info "=== SET_FORM CALLED ==="
    Rails.logger.info "Params share_token: #{params[:share_token]}"
    
    @form = Form.find_by!(share_token: params[:share_token])
    
    Rails.logger.info "Form loaded successfully:"
    Rails.logger.info "Form ID: #{@form.id}"
    Rails.logger.info "Form share_token: #{@form.share_token}"
    Rails.logger.info "Form name: #{@form.name}"
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Form not found with share_token: #{params[:share_token]}"
    render_error("Form not found", :not_found)
  end
  
  def set_or_create_response
    @form_response = find_or_create_response
  end
  
  def find_or_create_response
    # Try to find existing response by session
    existing_response = find_response_by_session
    
    if existing_response&.in_progress?
      return existing_response
    end
    
    # Create new response
    create_new_response
  end
  
  def find_response_by_session(session_id = nil)
    session_id ||= current_session_id
    return nil unless session_id
    
    @form.form_responses.find_by(session_id: session_id)
  end
  
  def create_new_response
    response_data = {
      form: @form,
      session_id: current_session_id,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      referrer_url: request.referer,
      started_at: Time.current,
      status: :in_progress
    }
    
    # Add UTM parameters if present
    response_data[:utm_data] = extract_utm_parameters if has_utm_parameters?
    
    @form.form_responses.create!(response_data)
  end
  
  def find_completed_response
    session_id = session[:completed_response_session_id]
    return nil unless session_id
    
    @form.form_responses.find_by(session_id: session_id, status: :completed)
  end
  
  # Question Management
  
  def find_current_question
    return nil unless @form_response
    
    Rails.logger.info "=== FIND_CURRENT_QUESTION DEBUG ==="
    Rails.logger.info "Form present: #{@form.present?}"
    Rails.logger.info "FormResponse present: #{@form_response.present?}"
    
    # Get IDs of questions that have been answered (including skipped ones)
    processed_question_ids = @form_response.question_responses
                                          .joins(:form_question)
                                          .pluck('form_questions.id')
    
    Rails.logger.info "Processed question IDs: #{processed_question_ids}"
    
    # Find the highest position of processed questions
    max_processed_position = @form_response.question_responses
                                          .joins(:form_question)
                                          .maximum('form_questions.position') || 0
    
    Rails.logger.info "Max processed position: #{max_processed_position}"
    
    # Get all questions starting from the next position
    remaining_questions = @form.form_questions
                              .where.not(id: processed_question_ids)
                              .where('position > ?', max_processed_position)
                              .order(:position)
    
    Rails.logger.info "Remaining questions count: #{remaining_questions.count}"
    
    # Find the first question that should be shown based on conditional logic
    remaining_questions.each do |question|
      Rails.logger.info "Evaluating question: #{question.title} (position: #{question.position})"
      
      if should_show_question?(question)
        Rails.logger.info "✓ Question should be shown: #{question.title}"
        return question
      else
        Rails.logger.info "✗ Question should be skipped: #{question.title}"
        # Auto-skip this question
        skip_question(question)
        # Continue to next question in the loop
      end
    end
    
    # No more questions to show
    Rails.logger.info "No more questions to show"
    nil
  end
  
  def find_question_by_id(question_id)
    @form.form_questions.find_by(id: question_id)
  end
  
  def should_show_question?(question)
    return true unless question.has_conditional_logic?
    
    Rails.logger.info "  Checking conditional logic for: #{question.title}"
    Rails.logger.info "  Conditional rules: #{question.conditional_rules}"
    
    result = question.should_show_for_response?(@form_response)
    Rails.logger.info "  Conditional result: #{result}"
    
    result
  end
  
  def skip_question(question)
    # Create a skipped response record
    @form_response.question_responses.create!(
      form_question: question,
      answer_data: {},
      skipped: true,
      response_time_ms: 0
    )
  end
  
  # Answer Processing
  
  def process_answer_submission
    answer_data = extract_answer_data
    
    # Validate the answer
    validation_result = validate_answer(answer_data)
    return validation_result unless validation_result[:valid]
    
    # Process standard answer first
    result = process_standard_answer(answer_data)
    
    # Check if this is a budget-related question and trigger adaptation
    if should_trigger_budget_adaptation?(answer_data[:value])
      trigger_budget_adaptation(answer_data[:value])
    end
    
    # Process through SuperAgent workflow if AI is enabled
    if @form.ai_enhanced? && @current_question.ai_enhanced?
      process_with_ai_workflow(answer_data)
    else
      result
    end
  end
  
  def extract_answer_data
    answer_params = params.require(:answer)
    
    # Add metadata
    {
      value: answer_params[:value],
      started_at: answer_params[:started_at],
      completed_at: Time.current.iso8601,
      question_type: @current_question.question_type,
      metadata: {
        response_time_ms: calculate_response_time(answer_params[:started_at]),
        user_agent: request.user_agent,
        ip_address: request.remote_ip
      }
    }
  end
  
  def validate_answer(answer_data)
    question_handler = @current_question.question_type_handler
    validation_errors = question_handler.validate_answer(answer_data[:value])
    
    if validation_errors.empty?
      { valid: true, processed_data: question_handler.process_answer(answer_data[:value]) }
    else
      { valid: false, errors: validation_errors }
    end
  end
  
  def process_with_ai_workflow(answer_data)
    begin
      # Trigger SuperAgent workflow for AI processing
      workflow_result = Forms::ResponseAgent.new.process_form_response(
        @form_response,
        @current_question,
        answer_data,
        workflow_context
      )
      
      { success: true, workflow_result: workflow_result }
    rescue => error
      Rails.logger.error "AI workflow error: #{error.message}"
      # Fallback to standard processing
      process_standard_answer(answer_data)
    end
  end
  
  def process_standard_answer(answer_data)
    question_response = @form_response.question_responses.build(
      form_question: @current_question,
      answer_data: answer_data,
      response_time_ms: answer_data.dig(:metadata, :response_time_ms)
    )
    
    if question_response.save
      { success: true, question_response: question_response }
    else
      { success: false, errors: question_response.errors.full_messages }
    end
  end
  
  def workflow_context
    {
      form_id: @form.id,
      form_response_id: @form_response.id,
      question_id: @current_question.id,
      session_id: current_session_id,
      user_context: extract_user_context
    }
  end
  
  # Response Completion
  
  def complete_form_response!
    return unless @form_response.can_be_completed?
    
    Rails.logger.info "=== COMPLETING FORM RESPONSE ==="
    Rails.logger.info "Form state before completion:"
    Rails.logger.info "Form present: #{@form.present?}"
    Rails.logger.info "Form share_token: #{@form&.share_token}"
    Rails.logger.info "Form ID: #{@form&.id}"
    
    completion_data = {
      completed_at: Time.current,
      completion_method: 'auto',
      final_question_count: @form.form_questions.count,
      total_response_time: calculate_total_response_time
    }
    
    @form_response.mark_completed!(completion_data)
    
    # Store completion data in session for thank you page
    session[:completion_data] = completion_data
    session[:completed_response_session_id] = @form_response.session_id
    
    # Trigger completion workflows
    trigger_completion_workflows
    
    # Update form analytics
    update_form_completion_analytics
    
    Rails.logger.info "Form state after completion:"
    Rails.logger.info "Form present: #{@form.present?}"
    Rails.logger.info "Form share_token: #{@form&.share_token}"
  end
  
  def trigger_completion_workflows
    # Trigger integrations and AI analysis
    Forms::CompletionWorkflowJob.perform_later(@form_response.id) if defined?(Forms::CompletionWorkflowJob)
  end
  
  # Response Handling
  
  def handle_successful_answer(result)
    # Update response activity
    @form_response.touch(:last_activity_at)
    
    # Check if form should be completed
    if should_complete_form?
      complete_form_response!
      render_completion_response
    else
      render_next_question_response(result)
    end
  end
  
  def handle_answer_error(result)
    respond_to do |format|
      format.html { 
        flash[:error] = result[:errors].join(', ')
        redirect_back(fallback_location: form_path(@form.share_token))
      }
      format.json { 
        render json: { 
          success: false, 
          errors: result[:errors],
          question_id: @current_question.id
        }, status: :unprocessable_entity 
      }
    end
  end
  
  def render_next_question_response(result)
    next_question = find_current_question
    
    respond_to do |format|
      format.html { redirect_to public_form_path(@form.share_token) }
      format.json { 
        render json: {
          success: true,
          next_question: next_question ? serialize_question(next_question) : nil,
          progress: @form_response.progress_percentage,
          completed: next_question.nil?
        }
      }
    end
  end
  
  def render_completion_response
    respond_to do |format|
      format.html { redirect_to thank_you_form_path(@form.share_token) }
      format.json { 
        render json: {
          success: true,
          completed: true,
          redirect_url: thank_you_form_path(@form.share_token)
        }
      }
    end
  end
  
  # Validation and Security
  
  def validate_form_access
    unless @form.published?
      render_error("Form is not available", :not_found)
      return false
    end
    
    # Check if form has expired (if expiration is set)
    if form_expired?
      render_error("Form has expired", :gone)
      return false
    end
    
    # Check response limits (if set)
    if response_limit_exceeded?
      render_error("Form is no longer accepting responses", :gone)
      return false
    end
    
    true
  end
  
  def form_expired?
    expiry_date = @form.form_settings.dig('expiry_date')
    expiry_date && Date.parse(expiry_date) < Date.current
  rescue
    false
  end
  
  def response_limit_exceeded?
    max_responses = @form.form_settings.dig('max_responses')
    max_responses && @form.responses_count >= max_responses.to_i
  end
  
  # Session Management
  
  def current_session_id
    session[:form_session_id] ||= generate_session_id
  end
  
  def generate_session_id
    "#{@form.id}_#{SecureRandom.hex(16)}_#{Time.current.to_i}"
  end
  
  def clear_response_session
    session.delete(:form_response_id)
    session.delete(:form_session_id)
  end
  
  # Analytics and Tracking
  
  def track_form_view
    # Increment view count (use Redis for high-frequency updates)
    Rails.cache.increment("form_views:#{@form.id}", 1)
    
    # Update database periodically (via background job)
    UpdateFormViewsJob.perform_later(@form.id) if defined?(UpdateFormViewsJob)
  end
  
  def track_form_abandonment(reason)
    # Track abandonment analytics
    Rails.cache.increment("form_abandons:#{@form.id}", 1)
    
    # Store abandonment reason for analysis
    abandonment_data = {
      form_id: @form.id,
      question_position: @form_response&.current_question_position,
      reason: reason,
      timestamp: Time.current
    }
    
    Rails.cache.lpush("form_abandonment_data:#{@form.id}", abandonment_data.to_json)
  end
  
  def update_form_completion_analytics
    # Update completion count
    @form.increment!(:completion_count)
    
    # Update cached completion rate
    Rails.cache.delete("form/#{@form.id}/completion_rate")
  end
  
  # Data Preparation and Serialization
  
  def prepare_question_data
    return unless @current_question
    
    @question_config = @current_question.question_config || {}
    @question_handler = @current_question.question_type_handler
    @validation_rules = extract_validation_rules
    @conditional_logic = @current_question.conditional_rules if @current_question.has_conditional_logic?
  end
  
  def serialize_question(question)
    {
      id: question.id,
      title: question.title,
      description: question.description,
      type: question.question_type,
      required: question.required?,
      position: question.position,
      configuration: question.question_config,
      validation_rules: question.validation_rules
    }
  end
  
  def extract_validation_rules
    rules = {}
    
    if @current_question.required?
      rules[:required] = true
    end
    
    # Add type-specific validation rules
    case @current_question.question_type
    when 'email'
      rules[:email] = true
    when 'phone'
      rules[:phone] = true
    when 'number'
      rules[:number] = true
      rules[:min] = @question_config['min_value'] if @question_config['min_value']
      rules[:max] = @question_config['max_value'] if @question_config['max_value']
    when 'text_short', 'text_long'
      rules[:min_length] = @question_config['min_length'] if @question_config['min_length']
      rules[:max_length] = @question_config['max_length'] if @question_config['max_length']
    end
    
    rules
  end
  
  # Utility Methods
  
  def calculate_response_time(started_at_string)
    return 0 unless started_at_string
    
    started_at = Time.parse(started_at_string)
    ((Time.current - started_at) * 1000).to_i
  rescue
    0
  end
  
  def calculate_total_response_time
    return 0 unless @form_response.started_at
    
    (Time.current - @form_response.started_at).to_i
  end
  
  def should_complete_form?
    # Check if all required questions are answered
    Rails.logger.info "=== CHECKING SHOULD COMPLETE FORM ==="
    Rails.logger.info "Form present: #{@form.present?}"
    Rails.logger.info "Form share_token: #{@form&.share_token}"
    Rails.logger.info "FormResponse present: #{@form_response.present?}"
    Rails.logger.info "can_be_completed?: #{@form_response.can_be_completed?}"
    
    current_question = find_current_question
    Rails.logger.info "find_current_question returned: #{current_question&.title}"
    Rails.logger.info "find_current_question.nil?: #{current_question.nil?}"
    
    result = @form_response.can_be_completed? && current_question.nil?
    Rails.logger.info "should_complete_form? result: #{result}"
    result
  end
  
  def extract_utm_parameters
    utm_params = {}
    
    %w[utm_source utm_medium utm_campaign utm_term utm_content].each do |param|
      utm_params[param] = params[param] if params[param].present?
    end
    
    utm_params
  end
  
  def has_utm_parameters?
    params.keys.any? { |key| key.start_with?('utm_') }
  end
  
  def extract_user_context
    {
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      referrer: request.referer,
      utm_data: extract_utm_parameters,
      session_id: current_session_id,
      timestamp: Time.current.iso8601
    }
  end
  
  # Budget Adaptation Methods
  
def should_trigger_budget_adaptation?(answer_value)
  return false unless @form_response
  return false unless @current_question
  
  Rails.logger.info "=== Checking Budget Trigger ==="
  Rails.logger.info "Question title: '#{@current_question.title}'"
  Rails.logger.info "Answer value: '#{answer_value}'"
  
  # Check if this is a budget-related question
  title_lower = @current_question.title.downcase
  description_lower = @current_question.description.to_s.downcase
  
  budget_keywords = [
    # English keywords
    'budget', 'price', 'cost', 'money', 'amount', 'spend', 'investment', 'financial',
    'funding', 'capital', 'expense', 'afford', 'pay', 'dollar', 'revenue',
    
    # Spanish keywords
    'presupuesto', 'precio', 'costo', 'dinero', 'cantidad', 'gastar', 'inversión',
    'financiero', 'financiamiento', 'capital', 'gasto', 'pagar', 'pago'
  ]
  
  # Check if the question mentions budget or money
  question_mentions_budget = budget_keywords.any? { |keyword| 
    title_lower.include?(keyword) || description_lower.include?(keyword)
  }
  
  Rails.logger.info "Question mentions budget: #{question_mentions_budget}"
  
  # For the specific question "Which is budget for AI projects?"
  ai_budget_question = title_lower.include?('budget') && (
    title_lower.include?('ai') || 
    title_lower.include?('artificial intelligence') ||
    title_lower.include?('machine learning') ||
    title_lower.include?('project')
  )
  
  Rails.logger.info "AI budget question detected: #{ai_budget_question}"
  
  # Check if the answer indicates any budget amount or constraint
  answer_text = answer_value.to_s.downcase
  answer_has_budget_info = has_budget_information?(answer_text)
  
  Rails.logger.info "Answer has budget info: #{answer_has_budget_info}"
  
  # Trigger if it's a budget question AND the answer contains budget information
  should_trigger = (question_mentions_budget || ai_budget_question) && answer_has_budget_info
  
  Rails.logger.info "Should trigger: #{should_trigger}"
  
  should_trigger
end
  
# Add this helper method
def has_budget_information?(answer_text)
  return false if answer_text.blank?
  
  # Check for numeric values
  has_numbers = answer_text.match?(/\d/)
  
  # Check for currency symbols or words
  currency_indicators = ['$', '€', '£', '¥', 'usd', 'dollar', 'euro', 'pound', 'peso']
  has_currency = currency_indicators.any? { |indicator| answer_text.include?(indicator) }
  
  # Check for budget-related words
  budget_words = [
    'budget', 'cost', 'price', 'money', 'amount', 'spend', 'investment',
    'limited', 'small', 'tight', 'low', 'high', 'large', 'big',
    'thousand', 'million', 'hundred', 'k', 'm',
    'presupuesto', 'limitado', 'pequeño', 'bajo', 'alto', 'grande',
    'mil', 'millón', 'cien', 'startup', 'bootstrap', 'enterprise'
  ]
  has_budget_words = budget_words.any? { |word| answer_text.include?(word) }
  
  # Check for written numbers
  written_numbers = ['one', 'two', 'three', 'four', 'five', 'ten', 'twenty', 'fifty', 'hundred',
                     'uno', 'dos', 'tres', 'cuatro', 'cinco', 'diez', 'veinte', 'cincuenta', 'cien']
  has_written_numbers = written_numbers.any? { |num| answer_text.include?(num) }
  
  # Return true if answer contains budget-related information
  has_numbers || has_currency || has_budget_words || has_written_numbers
end

# Also update the trigger_budget_adaptation method with better logging
def trigger_budget_adaptation(budget_answer)
  return unless @form.ai_enhanced?
  return unless @form.user.can_use_ai_features?
  
  Rails.logger.info "=== TRIGGERING BUDGET ADAPTATION ==="
  Rails.logger.info "Budget answer: '#{budget_answer}'"
  Rails.logger.info "Response ID: #{@form_response.id}"
  
  # Delay the job by 3 seconds to ensure WebSocket connection is established
  Forms::BudgetAdaptationJob.set(wait: 3.seconds).perform_later(@form_response.id, budget_answer)
  
  Rails.logger.info "Budget adaptation job queued with 3-second delay"
end
  
  def save_draft_data
    draft_data = params[:draft_data] || {}
    
    # Update form response with draft data
    @form_response.update(
      draft_data: draft_data,
      last_activity_at: Time.current
    )
    
    { success: true, message: 'Draft saved successfully' }
  rescue => error
    { success: false, error: error.message }
  end
  
  # Rendering Methods
  
  def render_form_layout
    render layout: 'public_form'
  end
  
  def render_thank_you_page
    render layout: 'public_form'
  end
  
  def render_json_response
    render json: {
      form: serialize_form,
      question: serialize_question(@current_question),
      progress: @progress_percentage,
      total_questions: @total_questions,
      response_id: @form_response.id
    }
  end
  
  def render_completion_json
    render json: {
      completed: true,
      form: serialize_form,
      completion_data: @completion_data,
      response_summary: @form_response&.response_summary
    }
  end
  
  def serialize_form
    {
      id: @form.id,
      name: @form.name,
      description: @form.description,
      share_token: @form.share_token,
      style_configuration: @form.style_configuration
    }
  end
  
  def render_error(message, status)
    respond_to do |format|
      format.html { 
        render 'errors/form_error', 
               locals: { message: message, status: status },
               status: status,
               layout: 'public_form'
      }
      format.json { 
        render json: { error: message }, status: status 
      }
    end
  end

  def test_dynamic_question
      form_response = FormResponse.find_by!(session_id: current_session_id)
      
      # Create a simple test question
      dynamic_question = DynamicQuestion.create!(
        form_response: form_response,
        generated_from_question: form_response.question_responses.last&.form_question,
        question_type: 'text_long',
        title: 'Test Dynamic Question',
        description: 'This is a test question to verify Turbo Streams are working.',
        generation_context: { trigger: 'test' }
      )

      Rails.logger.info "Created test dynamic question: #{dynamic_question.id}"
      Rails.logger.info "Target: budget_adaptation_#{form_response.id}"

      # Test the broadcast
      begin
        Turbo::StreamsChannel.broadcast_append_to(
          form_response,
          target: "budget_adaptation_#{form_response.id}",
          partial: "responses/budget_adaptation_question",
          locals: {
            dynamic_question: dynamic_question,
            form_response: form_response
          }
        )
        
        Rails.logger.info "Test broadcast sent successfully"
        render json: { success: true, message: "Test question created and broadcast sent" }
      rescue => error
        Rails.logger.error "Test broadcast failed: #{error.message}"
        render json: { success: false, error: error.message }
      end
    end

  def trigger_budget_test
    form_response_id = params[:form_response_id]
    budget_answer = params[:budget_answer] || '800 usd'
    
    Rails.logger.info "=== MANUAL BUDGET TEST TRIGGER ==="
    Rails.logger.info "Form Response ID: #{form_response_id}"
    Rails.logger.info "Budget Answer: #{budget_answer}"
    
    begin
      # Trigger the job directly
      Forms::BudgetAdaptationJob.perform_now(form_response_id, budget_answer)
      
      render json: { 
        success: true, 
        message: "Budget adaptation job triggered manually",
        form_response_id: form_response_id,
        budget_answer: budget_answer
      }
      
    rescue => error
      Rails.logger.error "Manual trigger failed: #{error.message}"
      render json: { 
        success: false, 
        error: error.message,
        backtrace: error.backtrace.first(5)
      }
    end
  end
end