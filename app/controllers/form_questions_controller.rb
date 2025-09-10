# frozen_string_literal: true

class FormQuestionsController < ApplicationController
  before_action :set_form
  before_action :set_question, only: [:show, :edit, :update, :destroy, :move_up, :move_down, :duplicate, :ai_enhance, :preview, :analytics]
  before_action :authorize_form_access
  before_action :authorize_question_access, only: [:show, :edit, :update, :destroy, :move_up, :move_down, :duplicate, :ai_enhance, :preview, :analytics]

  # GET /forms/:form_id/questions
  def index
    @questions = policy_scope(@form.form_questions)
                      .includes(:question_responses)
                      .order(:position)
    
    respond_to do |format|
      format.html
      format.json { render json: @questions }
    end
  end

  # Add this to your form_questions_controller.rb create method

def create
  @question = @form.form_questions.build(question_params)
  @question.position = @form.next_question_position if @question.position.blank?

  # Check if user can create payment questions
  if @question.question_type == 'payment' && !current_user.can_accept_payments?
    respond_to do |format|
      format.html { 
        redirect_to edit_form_path(@form), 
        alert: 'Payment questions are only available for Premium users. Please upgrade your account to accept payments.' 
      }
      format.json { 
        render json: { 
          error: 'Payment questions require Premium subscription',
          upgrade_required: true 
        }, status: :forbidden 
      }
    end
    return
  end

  if @question.save
    handle_form_structure_change

    respond_to do |format|
      format.html { redirect_to edit_form_path(@form), notice: 'Question was successfully created.' }
      format.json { render json: @question, status: :created }
    end
  else
    @question_types = FormQuestion::QUESTION_TYPES
    @ai_features = %w[smart_validation response_analysis dynamic_followup]
    
    respond_to do |format|
      format.html { render :new, status: :unprocessable_entity }
      format.json { render json: { errors: @question.errors.full_messages }, status: :unprocessable_entity }
    end
  end
end

  # GET /forms/:form_id/questions/:id
  def show
    @question_analytics = @question.analytics_summary(30.days)
    @recent_responses = @question.question_responses
                                 .includes(:form_response)
                                 .order(created_at: :desc)
                                 .limit(10)

    respond_to do |format|
      format.html
      format.json { render json: @question, include: [:question_responses] }
    end
  end

  # GET /forms/:form_id/questions/new
  def new
    @question = @form.form_questions.build
    @question.position = @form.next_question_position
    @question_types = FormQuestion::QUESTION_TYPES
    @ai_features = %w[smart_validation response_analysis dynamic_followup]
  end

  # POST /forms/:form_id/questions


  # GET /forms/:form_id/questions/:id/edit
  def edit
    @question_types = FormQuestion::QUESTION_TYPES
    @ai_features = %w[smart_validation response_analysis dynamic_followup]
    
    # Mejora: preparar preguntas con contexto enriquecido
    prepare_conditional_questions
    generate_conditional_suggestions
  end

  # PATCH/PUT /forms/:form_id/questions/:id
def update
  old_config = @question.question_config.dup if @question.question_config
  old_ai_config = @question.ai_config.dup if @question.ai_config

  # Check if user is trying to change to payment type and doesn't have premium
  if question_params[:question_type] == 'payment' && 
     @question.question_type != 'payment' && 
     !current_user.can_accept_payments?
    
    respond_to do |format|
      format.html { 
        redirect_to edit_form_path(@form), 
        alert: 'Payment questions are only available for Premium users. Please upgrade your account to accept payments.' 
      }
      format.json { 
        render json: { 
          error: 'Payment questions require Premium subscription',
          upgrade_required: true 
        }, status: :forbidden 
      }
    end
    return
  end

  if @question.update(question_params)
    handle_question_update(old_config, old_ai_config) if old_config || old_ai_config

    respond_to do |format|
      format.html { redirect_to edit_form_path(@form), notice: 'Question was successfully updated.' }
      format.json { render json: { success: true, question: @question } }
    end
  else
    @question_types = FormQuestion::QUESTION_TYPES
    @ai_features = %w[smart_validation response_analysis dynamic_followup]
    @conditional_questions = @form.form_questions.where.not(id: @question.id).order(:position)
    
    respond_to do |format|
      format.html { render :edit, status: :unprocessable_entity }
      format.json { render json: { errors: @question.errors.full_messages }, status: :unprocessable_entity }
    end
  end
end

  # DELETE /forms/:form_id/questions/:id
  def destroy
    position = @question.position
    @question.destroy!

    # Reorder remaining questions
    reorder_questions_after_deletion(position)
    handle_form_structure_change

    respond_to do |format|
      format.html { redirect_to edit_form_path(@form), notice: 'Question was successfully deleted.' }
      format.json { head :no_content }
    end
  end

  # POST /forms/:form_id/questions/:id/move_up
  def move_up
    if @question.position > 1
      swap_question_positions(@question, find_question_at_position(@question.position - 1))
      handle_form_structure_change

      respond_to do |format|
        format.html { redirect_to edit_form_path(@form), notice: 'Question moved up successfully.' }
        format.json { render json: { success: true, new_position: @question.reload.position } }
      end
    else
      respond_to do |format|
        format.html { redirect_to edit_form_path(@form), alert: 'Question is already at the top.' }
        format.json { render json: { error: 'Question is already at the top' }, status: :unprocessable_entity }
      end
    end
  end

  # POST /forms/:form_id/questions/:id/move_down
  def move_down
    max_position = @form.form_questions.maximum(:position)
    
    if @question.position < max_position
      swap_question_positions(@question, find_question_at_position(@question.position + 1))
      handle_form_structure_change

      respond_to do |format|
        format.html { redirect_to edit_form_path(@form), notice: 'Question moved down successfully.' }
        format.json { render json: { success: true, new_position: @question.reload.position } }
      end
    else
      respond_to do |format|
        format.html { redirect_to edit_form_path(@form), alert: 'Question is already at the bottom.' }
        format.json { render json: { error: 'Question is already at the bottom' }, status: :unprocessable_entity }
      end
    end
  end

  # POST /forms/:form_id/questions/:id/duplicate
def duplicate
  begin
    duplicated_question = @question.dup
    duplicated_question.title = "#{@question.title} (Copy)"
    duplicated_question.position = @form.next_question_position
    duplicated_question.save!

    handle_form_structure_change

    respond_to do |format|
      format.html { redirect_to edit_form_path(@form), notice: 'Question duplicated successfully.' }
      format.json { render json: duplicated_question, status: :created }
    end
  rescue StandardError => e
    respond_to do |format|
      format.html { redirect_to edit_form_path(@form), alert: "Failed to duplicate question: #{e.message}" }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end
end

  # POST /forms/:form_id/questions/:id/ai_enhance
  def ai_enhance
    unless @form.ai_enhanced?
      return render json: { error: 'AI features not enabled for this form' }, status: :unprocessable_entity
    end

    unless current_user.can_use_ai_features?
      return render json: { error: 'AI features require a premium subscription' }, status: :forbidden
    end

    enhancement_type = params[:enhancement_type] || 'smart_validation'
    enhancement_options = params[:enhancement_options] || {}

    begin
      result = enhance_question_with_ai(enhancement_type, enhancement_options)

      respond_to do |format|
        format.html { redirect_to edit_form_path(@form), notice: 'Question enhanced with AI successfully.' }
        format.json { render json: { success: true, result: result } }
      end
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_to edit_form_path(@form), alert: "AI enhancement failed: #{e.message}" }
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  # GET /forms/:form_id/questions/:id/preview
  def preview
    @preview_mode = true
    @sample_response = build_sample_response

    respond_to do |format|
      format.html { render 'form_questions/preview' }
      format.json { render json: { question: @question, sample_response: @sample_response } }
    end
  end

  # POST /forms/:form_id/questions/reorder
  def reorder
    question_ids = params[:question_ids]
    
    unless question_ids.is_a?(Array)
      return render json: { error: 'Invalid question_ids format' }, status: :bad_request
    end

    begin
      reorder_questions(question_ids)
      handle_form_structure_change

      respond_to do |format|
        format.html { redirect_to edit_form_path(@form), notice: 'Questions reordered successfully.' }
        format.json { render json: { success: true } }
      end
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_to edit_form_path(@form), alert: "Failed to reorder questions: #{e.message}" }
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  # GET /forms/:form_id/questions/:id/analytics
  def analytics
    @analytics_period = params[:period]&.to_i&.days || 30.days
    @question_analytics = @question.analytics_summary(@analytics_period)
    @response_distribution = calculate_response_distribution
    @performance_metrics = calculate_performance_metrics

    respond_to do |format|
      format.html
      format.json do
        render json: {
          analytics: @question_analytics,
          distribution: @response_distribution,
          performance: @performance_metrics
        }
      end
    end
  end

  private

  def prepare_conditional_questions
    @conditional_questions = @form.form_questions
                                  .where.not(id: @question.id)
                                  .where('position < ?', @question.position)
                                  .order(:position)
  end

  def set_form
    @form = current_user.forms.find(params[:form_id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to forms_path, alert: 'Form not found.' }
      format.json { render json: { error: 'Form not found' }, status: :not_found }
    end
  end

  def set_question
    @question = @form.form_questions.find(params[:id])
    
    # Enrich conditional questions with additional context
    @conditional_questions = @form.form_questions
                                  .where.not(id: @question.id)
                                  .where('position < ?', @question.position)
                                  .order(:position)
                                  .map do |q|
      # Add helper data for the UI
      q.define_singleton_method(:choice_options) do
        case question_type
        when 'single_choice', 'multiple_choice', 'checkbox'
          question_config&.dig('options') || []
        when 'yes_no', 'boolean'
          ['Yes', 'No']
        when 'rating', 'scale'
          min_val = question_config&.dig('min_value') || 1
          max_val = question_config&.dig('max_value') || 5
          (min_val..max_val).to_a.map(&:to_s)
        else
          []
        end
      end
      
      q.define_singleton_method(:reference_id) do
        id
      end
      
      q
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Question not found: #{params[:id]} in form #{@form.id}"
    respond_to do |format|
      format.html { 
        redirect_to edit_form_path(@form), alert: "Question not found or has been deleted. (ID: #{params[:id]})" 
      }
      format.json { 
        render json: { error: "Question not found (ID: #{params[:id]})" }, status: :not_found 
      }
    end
    return
  end

  def validate_conditional_logic
    return unless @question.conditional_enabled? && @question.conditional_logic.present?
    
    rules = @question.conditional_logic['rules'] || []
    validation_errors = []
    
    rules.each_with_index do |rule, index|
      # Check if referenced question exists
      referenced_question = @form.form_questions.find_by(id: rule['question_id'])
      unless referenced_question
        validation_errors << "Rule #{index + 1}: Referenced question no longer exists"
        next
      end
      
      # Check if referenced question comes before current question
      if referenced_question.position >= @question.position
        validation_errors << "Rule #{index + 1}: Can only reference questions that appear before this one"
      end
      
      # Validate operator-value combinations
      case rule['operator']
      when 'is_empty', 'is_not_empty'
        # These operators don't need values
      when 'equals', 'not_equals', 'contains', 'starts_with', 'ends_with'
        if rule['value'].blank?
          validation_errors << "Rule #{index + 1}: Value is required for '#{rule['operator']}' condition"
        end
      when 'greater_than', 'less_than', 'greater_than_or_equal', 'less_than_or_equal'
        if rule['value'].blank? || !numeric?(rule['value'])
          validation_errors << "Rule #{index + 1}: Numeric value is required for '#{rule['operator']}' condition"
        end
      end
      
      # Validate value matches question type expectations
      if referenced_question.question_type == 'yes_no' && rule['value'].present?
        unless ['yes', 'no', 'true', 'false'].include?(rule['value'].downcase)
          validation_errors << "Rule #{index + 1}: Value should be 'Yes' or 'No' for yes/no questions"
        end
      end
    end
    
    if validation_errors.any?
      @question.errors.add(:conditional_logic, validation_errors.join('; '))
      return false
    end
    
    true
  end

  def numeric?(str)
    Float(str) != nil rescue false
  end

  def generate_conditional_suggestions
    @conditional_suggestions = {}
    
    @conditional_questions.each do |q|
      suggestions = case q.question_type
      when 'single_choice', 'multiple_choice'
        {
          operators: ['equals', 'not_equals', 'in_list', 'not_in_list'],
          values: q.choice_options,
          examples: [
            "Show when #{q.title} is exactly '#{q.choice_options.first}'",
            "Show when #{q.title} is any of: #{q.choice_options.first(2).join(', ')}"
          ]
        }
      when 'yes_no'
        {
          operators: ['equals', 'not_equals'],
          values: ['Yes', 'No'],
          examples: [
            "Show when #{q.title} is Yes",
            "Show when #{q.title} is No"
          ]
        }
      when 'text_long', 'text_short'
        {
          operators: ['contains', 'not_contains', 'is_empty', 'is_not_empty'],
          values: [],
          examples: [
            "Show when #{q.title} contains 'keyword'",
            "Show when #{q.title} is not empty"
          ]
        }
      when 'rating', 'scale'
        min_val = q.question_config&.dig('min_value') || 1
        max_val = q.question_config&.dig('max_value') || 5
        mid_val = (min_val + max_val) / 2
        
        {
          operators: ['equals', 'greater_than', 'less_than', 'greater_than_or_equal', 'less_than_or_equal'],
          values: (min_val..max_val).to_a.map(&:to_s),
          examples: [
            "Show when #{q.title} is greater than #{mid_val}",
            "Show when #{q.title} equals #{max_val}"
          ]
        }
      else
        {
          operators: ['equals', 'contains', 'is_empty'],
          values: [],
          examples: []
        }
      end
      
      @conditional_suggestions[q.id] = suggestions
    end
  end

  def preview_conditional_logic
    return unless request.xhr? && params[:conditional_preview]
    
    begin
      preview_rules = JSON.parse(params[:conditional_preview])
      preview_text = generate_preview_text(preview_rules)
      
      render json: { 
        success: true, 
        preview: preview_text,
        warnings: validate_preview_rules(preview_rules)
      }
    rescue JSON::ParserError
      render json: { success: false, error: 'Invalid rule format' }
    end
  end

  def generate_preview_text(rules)
    return "No rules configured" if rules.empty?
    
    rule_texts = rules.map.with_index do |rule, index|
      question = @conditional_questions.find { |q| q.id == rule['question_id'] }
      next "Rule #{index + 1}: Invalid question" unless question
      
      operator_text = case rule['operator']
      when 'equals' then 'is exactly'
      when 'not_equals' then 'is not'
      when 'contains' then 'contains'
      when 'not_contains' then 'does not contain'
      when 'is_empty' then 'is empty'
      when 'is_not_empty' then 'has any answer'
      when 'greater_than' then 'is greater than'
      when 'less_than' then 'is less than'
      else rule['operator']
      end
      
      value_text = rule['value'].present? ? " '#{rule['value']}'" : ""
      "when '#{question.title}' #{operator_text}#{value_text}"
    end.compact
    
    logic_operator = params[:logic_operator] || 'and'
    connector = logic_operator == 'and' ? ' AND ' : ' OR '
    
    "Show this question #{rule_texts.join(connector)}"
  end

  def validate_preview_rules(rules)
    warnings = []
    
    rules.each_with_index do |rule, index|
      question = @conditional_questions.find { |q| q.id == rule['question_id'] }
      next unless question
      
      # Check for potential issues
      if question.question_type == 'single_choice' && rule['operator'] == 'equals'
        available_options = question.choice_options
        if available_options.any? && rule['value'].present? && !available_options.include?(rule['value'])
          warnings << "Rule #{index + 1}: '#{rule['value']}' is not one of the available options"
        end
      end
      
      if question.question_type == 'yes_no' && rule['value'].present?
        unless ['yes', 'no'].include?(rule['value'].downcase)
          warnings << "Rule #{index + 1}: For yes/no questions, value should be 'Yes' or 'No'"
        end
      end
    end
    
    warnings
  end

  def authorize_form_access
    authorize @form, :edit?
  end

  def authorize_question_access
    authorize @question
  end


  def question_params
    params.require(:form_question).permit(
      :title, :description, :question_type, :required, :position,
      :ai_enhanced, :conditional_enabled, :hidden,
      question_config: [
        :min_value, :max_value, :step, :min_length, :max_length, :max_size_mb,
        :multiple, :placeholder, :format,
        options: [],
        items: [],
        categories: [],
        labels: {},
        allowed_types: []
      ],
      ai_config: {},
      conditional_logic: {}
    )
  end

  def handle_form_structure_change
    # Update form cache
    @form.update_form_cache if @form.respond_to?(:update_form_cache)
    
    # Regenerate workflow if AI is enabled
    if @form.ai_enhanced?
      Forms::WorkflowGenerationJob.perform_later(@form.id)
    end
  end

  def handle_question_update(old_config, old_ai_config)
    # Check if question configuration changed significantly
    if question_config_changed?(old_config) || ai_config_changed?(old_ai_config)
      handle_form_structure_change
      
      # Trigger analytics recalculation if question has responses
      if @question.question_responses.any?
        Forms::ResponseAnalysisJob.perform_later(@question.id)
      end
    end
  end

def question_config_changed?(old_config)
  return true if old_config.nil? && @question.question_config.present?
  return true if old_config.present? && @question.question_config.nil?
  return false if old_config.nil? && @question.question_config.nil?
  
  @question.question_config != old_config
end

def ai_config_changed?(old_ai_config)
  return true if old_ai_config.nil? && @question.ai_config.present?
  return true if old_ai_config.present? && @question.ai_config.nil?
  return false if old_ai_config.nil? && @question.ai_config.nil?
  
  @question.ai_config != old_ai_config
end

  def reorder_questions_after_deletion(deleted_position)
    @form.form_questions.where('position > ?', deleted_position)
         .update_all('position = position - 1')
  end

  def swap_question_positions(question1, question2)
    return unless question2

    ActiveRecord::Base.transaction do
      pos1 = question1.position
      pos2 = question2.position
      
      # Use a temporary position to avoid unique constraint issues
      temp_position = -1
      question1.update!(position: temp_position)
      question2.update!(position: pos1)
      question1.update!(position: pos2)
    end
  end

  def find_question_at_position(position)
    @form.form_questions.find_by(position: position)
  end

  def reorder_questions(question_ids)
    ActiveRecord::Base.transaction do
      question_ids.each_with_index do |question_id, index|
        question = @form.form_questions.find(question_id)
        question.update!(position: index + 1)
      end
    end
  end

  def enhance_question_with_ai(enhancement_type, options)
    case enhancement_type
    when 'smart_validation'
      enhance_with_smart_validation(options)
    when 'response_analysis'
      enhance_with_response_analysis(options)
    when 'dynamic_followup'
      enhance_with_dynamic_followup(options)
    else
      raise ArgumentError, "Unknown enhancement type: #{enhancement_type}"
    end
  end

  def enhance_with_smart_validation(options)
    # Enable AI-powered validation for the question
    ai_config = @question.ai_config || {}
    ai_config['features'] ||= []
    ai_config['features'] << 'smart_validation' unless ai_config['features'].include?('smart_validation')
    ai_config['validation_rules'] = generate_smart_validation_rules(options)
    
    @question.update!(
      ai_enhanced: true,
      ai_config: ai_config
    )

    { enhancement_type: 'smart_validation', features_added: ['smart_validation'] }
  end

  def enhance_with_response_analysis(options)
    # Enable AI-powered response analysis
    ai_config = @question.ai_config || {}
    ai_config['features'] ||= []
    ai_config['features'] << 'response_analysis' unless ai_config['features'].include?('response_analysis')
    ai_config['analysis_config'] = {
      sentiment_analysis: options[:sentiment_analysis] != false,
      keyword_extraction: options[:keyword_extraction] != false,
      quality_scoring: options[:quality_scoring] != false
    }
    
    @question.update!(
      ai_enhanced: true,
      ai_config: ai_config
    )

    { enhancement_type: 'response_analysis', features_added: ['response_analysis'] }
  end

  def enhance_with_dynamic_followup(options)
    # Enable AI-powered dynamic follow-up questions
    ai_config = @question.ai_config || {}
    ai_config['features'] ||= []
    ai_config['features'] << 'dynamic_followup' unless ai_config['features'].include?('dynamic_followup')
    ai_config['followup_config'] = {
      max_followups: options[:max_followups] || 2,
      trigger_conditions: options[:trigger_conditions] || ['interesting_response', 'incomplete_answer'],
      followup_style: options[:followup_style] || 'conversational'
    }
    
    @question.update!(
      ai_enhanced: true,
      ai_config: ai_config
    )

    { enhancement_type: 'dynamic_followup', features_added: ['dynamic_followup'] }
  end

  def generate_smart_validation_rules(options)
    # Generate AI-powered validation rules based on question type and options
    base_rules = {
      enabled: true,
      confidence_threshold: options[:confidence_threshold] || 0.7,
      validation_prompts: generate_validation_prompts
    }

    case @question.question_type
    when 'email'
      base_rules[:email_specific] = {
        check_disposable: options[:check_disposable] != false,
        check_format: true,
        check_domain: options[:check_domain] != false
      }
    when 'text_long'
      base_rules[:text_analysis] = {
        min_quality_score: options[:min_quality_score] || 0.6,
        check_coherence: options[:check_coherence] != false,
        check_relevance: options[:check_relevance] != false
      }
    end

    base_rules
  end

  def generate_validation_prompts
    {
      system_prompt: "You are an expert form validator. Analyze the response for quality, relevance, and completeness.",
      validation_prompt: "Validate this response for the question: '#{@question.title}'. Consider appropriateness, completeness, and quality."
    }
  end

  def build_sample_response
    # Build a sample response for preview purposes
    case @question.question_type
    when 'text_short'
      'Sample short text response'
    when 'text_long'
      'This is a sample long text response that demonstrates how the question would appear to users filling out the form.'
    when 'email'
      'user@example.com'
    when 'multiple_choice'
      @question.choice_options.first if @question.choice_options.any?
    when 'rating'
      config = @question.rating_config
      ((config[:min] + config[:max]) / 2).to_i
    else
      'Sample response'
    end
  end

  def calculate_response_distribution
    return {} unless @question.question_responses.any?

    case @question.question_type
    when 'multiple_choice', 'single_choice'
      calculate_choice_distribution
    when 'rating', 'scale', 'nps_score'
      calculate_rating_distribution
    when 'yes_no', 'boolean'
      calculate_boolean_distribution
    else
      calculate_text_distribution
    end
  end

  def calculate_choice_distribution
    responses = @question.question_responses.where.not(answer_text: [nil, ''])
    total = responses.count
    return {} if total.zero?

    distribution = responses.group(:answer_text).count
    distribution.transform_values { |count| (count.to_f / total * 100).round(2) }
  end

  def calculate_rating_distribution
    responses = @question.question_responses.where.not(answer_text: [nil, ''])
    total = responses.count
    return {} if total.zero?

    distribution = responses.group(:answer_text).count
    distribution.transform_values { |count| (count.to_f / total * 100).round(2) }
  end

  def calculate_boolean_distribution
    responses = @question.question_responses.where.not(answer_text: [nil, ''])
    total = responses.count
    return {} if total.zero?

    yes_count = responses.where(answer_text: ['yes', 'true', '1']).count
    no_count = total - yes_count

    {
      'Yes' => (yes_count.to_f / total * 100).round(2),
      'No' => (no_count.to_f / total * 100).round(2)
    }
  end

  def calculate_text_distribution
    responses = @question.question_responses.where.not(answer_text: [nil, ''])
    total = responses.count
    return {} if total.zero?

    # For text responses, show length distribution
    length_ranges = {
      'Short (1-50 chars)' => responses.where('LENGTH(answer_text) BETWEEN 1 AND 50').count,
      'Medium (51-200 chars)' => responses.where('LENGTH(answer_text) BETWEEN 51 AND 200').count,
      'Long (201+ chars)' => responses.where('LENGTH(answer_text) > 200').count
    }

    length_ranges.transform_values { |count| (count.to_f / total * 100).round(2) }
  end

  def calculate_performance_metrics
    responses = @question.question_responses
    total_responses = responses.count

    return {} if total_responses.zero?

    {
      completion_rate: @question.completion_rate,
      average_response_time: @question.average_response_time_seconds,
      skip_rate: calculate_skip_rate,
      quality_score: calculate_average_quality_score,
      engagement_score: calculate_engagement_score
    }
  end

  def calculate_skip_rate
    total_responses = @question.question_responses.count
    return 0.0 if total_responses.zero?

    skipped_responses = @question.question_responses.where(skipped: true).count
    (skipped_responses.to_f / total_responses * 100).round(2)
  end

  def calculate_average_quality_score
    responses_with_quality = @question.question_responses.where.not(quality_score: nil)
    return 0.0 if responses_with_quality.empty?

    responses_with_quality.average(:quality_score).to_f.round(2)
  end

  def calculate_engagement_score
    # Calculate engagement based on response time and completion
    responses = @question.question_responses.where.not(time_spent_seconds: [nil, 0])
    return 0.0 if responses.empty?

    avg_time = responses.average(:time_spent_seconds)
    completion_rate = @question.completion_rate

    # Normalize engagement score (0-100)
    time_score = [100 - (avg_time / 60.0 * 10), 0].max # Penalize very long times
    engagement = (completion_rate + time_score) / 2

    engagement.round(2)
  end
end