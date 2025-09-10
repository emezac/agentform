# frozen_string_literal: true

class FormsController < ApplicationController
  include PaymentErrorHandling
  include PaymentAnalyticsTrackable
  
  before_action :authenticate_user!
  before_action :set_form, only: [:show, :edit, :update, :destroy, :publish, :unpublish, :duplicate, :analytics, :export, :preview, :responses, :download_responses, :payment_setup_status, :has_payment_questions]
  before_action :authorize_form, only: [:show, :edit, :update, :destroy, :publish, :unpublish, :analytics, :preview]

  # GET /forms
  def index
    @forms = policy_scope(Form)
                        .includes(:form_questions, :form_responses)
                        .order(created_at: :desc)
    
    # Permit and extract parameters to avoid warnings
    permitted_params = params.permit(:user_id, :query, :status, :category, :sort_by, :sort_direction, :commit)
    
    # For superadmin, add user filtering capability
    if current_user.superadmin? && permitted_params[:user_id].present?
      @forms = @forms.where(user_id: permitted_params[:user_id])
    end

    # Apply search filter
    if permitted_params[:query].present?
      @forms = @forms.where("name ILIKE ? OR description ILIKE ?", 
                           "%#{permitted_params[:query]}%", 
                           "%#{permitted_params[:query]}%")
    end

    # Apply status filter
    if permitted_params[:status].present? && Form.statuses.key?(permitted_params[:status])
      @forms = @forms.where(status: permitted_params[:status])
    end

    # Apply category filter
    if permitted_params[:category].present? && Form.categories.key?(permitted_params[:category])
      @forms = @forms.where(category: permitted_params[:category])
    end

    # Apply sorting
    case permitted_params[:sort_by]
    when 'name'
      @forms = @forms.order(:name)
    when 'responses'
      @forms = @forms.order(:responses_count)
    when 'completion_rate'
      @forms = @forms.order(:completions_count)
    else
      @forms = @forms.order(created_at: :desc)
    end

    respond_to do |format|
      format.html
      format.json { render json: @forms }
    end
  end

  # GET /forms/:id
  def show
    @form_questions = @form.form_questions.includes(:question_responses)
    @recent_responses = @form.form_responses.includes(:question_responses)
                             .order(created_at: :desc)
                             .limit(10)

    respond_to do |format|
      format.html
      format.json { render json: @form, include: [:form_questions, :form_responses] }
    end
  end

  # GET /forms/new
  def new
    @form = current_user.forms.build
    authorize @form
    @form.assign_attributes(default_form_settings)
    @templates = [] # FormTemplate.public_templates.featured - will be implemented later
  end

  # GET /forms/new_from_ai
  def new_from_ai
    authorize Form, :create?
    
    # Check if user can use AI features
    unless current_user.can_use_ai_features?
      redirect_to new_form_path, alert: 'AI form generation requires a premium subscription.'
      return
    end

    # Check AI credits
    if current_user.ai_credits_remaining <= 0
      redirect_to new_form_path, alert: 'You have exceeded your monthly AI usage limit. Please upgrade your plan.'
      return
    end

    @ai_credits_remaining = current_user.ai_credits_remaining
    @estimated_cost = 0.05 # Base cost for form generation
  end

  # POST /forms
  def create
    @form = current_user.forms.build(form_params)
    authorize @form
    @form.assign_attributes(default_form_settings) if @form.form_settings.blank?
    @form.assign_attributes(default_ai_configuration) if @form.ai_configuration.blank?

    # Check subscription tier for AI features
    if @form.ai_enabled? && !current_user.can_use_ai_features?
      @form.ai_enabled = false
      flash.now[:alert] = 'AI features require a premium subscription. Form created without AI enhancements.'
    end

    if @form.save
      # Trigger workflow generation if AI is enabled and user has access
      if @form.ai_enabled? && current_user.can_use_ai_features?
        Forms::WorkflowGenerationJob.perform_later(@form.id)
      end

      respond_to do |format|
        format.html { redirect_to edit_form_path(@form), notice: 'Form was successfully created.' }
        format.json { render json: @form, status: :created }
      end
    else
      @templates = [] # FormTemplate.public_templates.featured - will be implemented later
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @form.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /forms/generate_from_ai
  def generate_from_ai
    authorize Form, :create?
    
    # Check if user can use AI features
    unless current_user.can_use_ai_features?
      respond_to do |format|
        format.html { redirect_to new_from_ai_forms_path, alert: 'AI form generation requires a premium subscription.' }
        format.json { render json: { error: 'AI features require a premium subscription' }, status: :forbidden }
      end
      return
    end

    # Check AI credits
    if current_user.ai_credits_remaining <= 0
      respond_to do |format|
        format.html { redirect_to new_from_ai_forms_path, alert: 'You have exceeded your monthly AI usage limit. Please upgrade your plan.' }
        format.json { render json: { error: 'Monthly AI usage limit exceeded' }, status: :forbidden }
      end
      return
    end

    # Extract and validate parameters
    generation_params = ai_generation_params
    
    # Validate parameters before processing
    validation_errors = validate_generation_params(generation_params)
    if validation_errors.any?
      respond_to do |format|
        format.html { 
          flash[:alert] = validation_errors.join(', ')
          redirect_to new_from_ai_forms_path 
        }
        format.json { 
          render json: { 
            error: validation_errors.first,
            errors: validation_errors 
          }, status: :unprocessable_entity 
        }
      end
      return
    end
    
    begin
      # Use the real AI workflow for form generation
      Rails.logger.info "Invoking AI form generation workflow"
      
      # Determine input type and prepare parameters
      input_type = generation_params[:document].present? ? 'document' : 'prompt'
      content_input = input_type == 'document' ? generation_params[:document] : generation_params[:prompt]
      
      # Prepare metadata for the workflow
      metadata = {
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        max_questions: generation_params[:max_questions] || 10,
        complexity_preference: generation_params[:complexity] || 'moderate',
        session_id: session.id
      }
      
      # Execute the AI workflow
      workflow_result = Forms::AiFormGenerationWorkflow.execute(
        user_id: current_user.id,
        content_input: content_input,
        input_type: input_type,
        metadata: metadata
      )

      if workflow_result[:success]
        @form = workflow_result[:form]
        
        respond_to do |format|
          format.html { redirect_to edit_form_path(@form), notice: 'AI form generated successfully!' }
          format.json { 
            render json: { 
              success: true, 
              form: @form.as_json(include: :form_questions), 
              redirect_url: edit_form_path(@form),
              message: 'AI form generated successfully!'
            } 
          }
        end
      else
        respond_to do |format|
          format.html { 
            flash[:alert] = workflow_result[:message] || workflow_result[:error] || 'Failed to generate form'
            redirect_to new_from_ai_forms_path
          }
          format.json { 
            render json: { 
              error: workflow_result[:message] || workflow_result[:error] || 'Failed to generate form',
              error_type: workflow_result[:error_type] || 'generation_error'
            }, status: :unprocessable_entity 
          }
        end
      end

    rescue StandardError => e
      Rails.logger.error "AI form generation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      error_message = case e.message
      when /Monthly AI usage limit exceeded/
        'You have exceeded your monthly AI usage limit. Please upgrade your plan.'
      when /Content too long/
        'The provided content is too long. Please provide content with fewer than 5000 words.'
      when /Content too short/
        'Please provide more detailed information to generate a comprehensive form.'
      when /Unsupported file type/
        'Please upload a PDF, Markdown, or text file.'
      when /File too large/
        'The uploaded file is too large. Please upload a file smaller than 10MB.'
      else
        'An error occurred while generating your form. Please try again.'
      end

      respond_to do |format|
        format.html { 
          flash[:alert] = error_message
          redirect_to new_from_ai_forms_path
        }
        format.json { 
          render json: { 
            error: error_message,
            error_type: 'exception'
          }, status: :unprocessable_entity 
        }
      end
    end
  end

  # GET /forms/:id/edit
  def edit
    @form_questions = @form.form_questions.order(:position)
    @question_types = FormQuestion::QUESTION_TYPES
    @ai_features = %w[response_analysis dynamic_questions sentiment_analysis lead_scoring]
    @can_use_ai = current_user.can_use_ai_features?
  end

  # PATCH/PUT /forms/:id
  def update
    old_ai_config = @form.ai_configuration.dup
    old_structure = @form.form_questions.pluck(:id, :position, :question_type)

    # Check subscription tier for AI features
    if form_params[:ai_enabled] == 'true' && !current_user.can_use_ai_features?
      @form.errors.add(:ai_enabled, 'requires a premium subscription')
      @form_questions = @form.form_questions.order(:position)
      @question_types = FormQuestion::QUESTION_TYPES
      @ai_features = %w[response_analysis dynamic_questions sentiment_analysis lead_scoring]
      @can_use_ai = current_user.can_use_ai_features?
      
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { error: 'AI features require a premium subscription' }, status: :unprocessable_entity }
      end
      return
    end

    if @form.update(form_params)
      handle_form_update(old_ai_config, old_structure)

      respond_to do |format|
        format.html { redirect_to @form, notice: 'Form was successfully updated.' }
        format.json { render json: @form }
      end
    else
      @form_questions = @form.form_questions.order(:position)
      @question_types = FormQuestion::QUESTION_TYPES
      @ai_features = %w[response_analysis dynamic_questions sentiment_analysis lead_scoring]
      @can_use_ai = current_user.can_use_ai_features?
      
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @form.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /forms/:id
  def destroy
    @form.destroy!

    respond_to do |format|
      format.html { redirect_to forms_path, notice: 'Form was successfully deleted.' }
      format.json { head :no_content }
    end
  end

  # POST /forms/:id/publish
  def publish
    # Basic form validation
    if @form.form_questions.empty?
      error_message = if @form.ai_enabled?
        'This AI-generated form appears to be incomplete. Please regenerate the form or add questions manually before publishing.'
      else
        'Cannot publish form without questions. Please add at least one question before publishing.'
      end
      
      respond_to do |format|
        format.html { redirect_to edit_form_path(@form), alert: error_message }
        format.json { render json: { error: error_message }, status: :unprocessable_entity }
        format.turbo_stream { 
          render turbo_stream: turbo_stream.replace('flash-messages', 
            partial: 'shared/flash_message', 
            locals: { type: 'alert', message: error_message }
          )
        }
      end
      return
    end

    # Pre-publish payment validation - this will raise PaymentValidationError if validation fails
    perform_pre_publish_validation

    begin
      @form.update!(status: 'published', published_at: Time.current)
      
      redirect_to @form, notice: 'Form has been published successfully.'
    rescue ActiveRecord::RecordInvalid => e
      error_message = handle_publish_validation_error(e)
      redirect_to edit_form_path(@form), alert: error_message
    end
  end

  # POST /forms/:id/unpublish
  def unpublish
    @form.update!(status: 'draft', published_at: nil)
    
    respond_to do |format|
      format.html { redirect_to @form, notice: 'Form has been unpublished.' }
      format.json { render json: { status: 'draft' } }
    end
  end

  # POST /forms/:id/duplicate
  def duplicate
    begin
      duplicated_form = Forms::ManagementAgent.new.duplicate_form(@form, current_user, {
        name: "#{@form.name} (Copy)",
        status: 'draft'
      })

      respond_to do |format|
        format.html { redirect_to edit_form_path(duplicated_form), notice: 'Form duplicated successfully.' }
        format.json { render json: duplicated_form, status: :created }
      end
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_to @form, alert: "Failed to duplicate form: #{e.message}" }
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  # GET /forms/:id/analytics
  def analytics
    @analytics_period = params[:period]&.to_i&.days || 30.days
    @analytics_data = @form.cached_analytics_summary(period: @analytics_period)
    
    @question_analytics = @form.form_questions.includes(:question_responses)
                               .map { |q| [q, q.analytics_summary(@analytics_period)] }
                               .to_h

    @response_trends = @form.form_analytics
                            .for_period(@analytics_period.ago.to_date, Date.current)
                            .daily
                            .order(:date)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          summary: @analytics_data,
          questions: @question_analytics,
          trends: @response_trends
        }
      end
    end
  end

  # GET /forms/:id/export
  def export
    export_format = params[:format] || 'csv'
    export_options = {
      format: export_format,
      include_metadata: params[:include_metadata] == 'true',
      date_range: params[:date_range]
    }

    begin
      export_data = Forms::ManagementAgent.new.export_form_data(@form, export_options)
      
      respond_to do |format|
        format.csv do
          send_data export_data[:content], 
                    filename: export_data[:filename],
                    type: 'text/csv'
        end
        format.json do
          render json: {
            download_url: export_data[:download_url],
            expires_at: export_data[:expires_at]
          }
        end
      end
    rescue StandardError => e
      respond_to do |format|
        format.html { redirect_to analytics_form_path(@form), alert: "Export failed: #{e.message}" }
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  # GET /forms/:id/preview
  def preview
    @preview_mode = true
    @form_response = @form.form_responses.build
    
    respond_to do |format|
      format.html { render 'forms/preview' }
      format.json { render json: @form, include: :form_questions }
    end
  end

  # GET /forms/:id/responses
  def responses
    authorize @form, :responses?
    
    @responses = @form.form_responses
                      .includes(:question_responses, :dynamic_questions)
                      .order(created_at: :desc)
                      .page(params[:page]).per(20)

    respond_to do |format|
      format.html
      format.csv { download_responses_csv }
    end
  end

  # GET /forms/:id/download_responses
  def download_responses
    authorize @form, :download_responses?
    
    @responses = @form.form_responses
                      .completed
                      .includes(:question_responses, :dynamic_questions)
                      .order(completed_at: :desc)

    csv_data = download_responses_csv
    send_data csv_data,
              filename: "#{@form.name.parameterize}_responses_#{Date.current}.csv",
              type: 'text/csv'
  end

  # GET /forms/:id/payment_setup_status
  def payment_setup_status
    authorize @form, :show?
    
    setup_status = @form.user.payment_setup_status
    
    respond_to do |format|
      format.json do
        render json: {
          has_payment_questions: @form.has_payment_questions?,
          stripe_configured: setup_status[:stripe_configured],
          premium_subscription: setup_status[:premium_subscription],
          can_accept_payments: setup_status[:can_accept_payments],
          setup_complete: @form.payment_setup_complete?,
          completion_percentage: setup_status[:setup_completion_percentage],
          missing_requirements: @form.payment_setup_requirements
        }
      end
    end
  end

  # GET /forms/:id/has_payment_questions
  def has_payment_questions
    authorize @form, :show?
    
    respond_to do |format|
      format.json do
        render json: {
          has_payment_questions: @form.has_payment_questions?,
          payment_questions_count: @form.payment_questions.count
        }
      end
    end
  end

  # POST /forms/:id/track_setup_abandonment
  def track_setup_abandonment
    authorize @form, :show?
    
    if @form.has_payment_questions? && !@form.payment_setup_complete?
      track_payment_event(
        'payment_setup_abandoned',
        user: current_user,
        context: {
          form_id: @form.id,
          form_title: @form.title,
          abandonment_point: params[:abandonment_point] || 'form_editor',
          time_spent: params[:time_spent]&.to_i || 0,
          setup_progress: current_user.payment_setup_status[:setup_completion_percentage],
          missing_requirements: @form.payment_setup_requirements
        }
      )
    end
    
    head :ok
  end

  private

  def validate_generation_params(params)
    errors = []
    
    # Must have either prompt or document
    if params[:prompt].blank? && (params[:document].blank? || params[:document].size == 0)
      errors << "Please provide either a text prompt or upload a document"
      return errors
    end
    
    # Validate prompt if provided
    if params[:prompt].present?
      prompt = params[:prompt].strip
      if prompt.length < 20
        errors << "Prompt must be at least 20 characters long"
      elsif prompt.length > 10000
        errors << "Prompt is too long (maximum 10,000 characters)"
      end
      
      # Check for potentially problematic content
      if prompt.match?(/\A\s*\z/) # Only whitespace
        errors << "Prompt cannot be empty or contain only whitespace"
      end
    end
    
    # Validate document if provided
    if params[:document].present? && params[:document].respond_to?(:size)
      document = params[:document]
      
      # Check file size (10MB limit)
      if document.size > 10.megabytes
        errors << "File size must be less than 10MB"
      end
      
      # Check file type
      allowed_types = ['application/pdf', 'text/markdown', 'text/plain', 'text/md']
      allowed_extensions = ['.pdf', '.md', '.txt', '.markdown']
      
      content_type_valid = allowed_types.include?(document.content_type)
      extension_valid = allowed_extensions.any? { |ext| 
        document.original_filename&.downcase&.end_with?(ext) 
      }
      
      unless content_type_valid || extension_valid
        errors << "Please upload a PDF, Markdown (.md), or text (.txt) file"
      end
    end
    
    errors
  end

  def set_form
    if current_user.superadmin?
      @form = Form.find(params[:id])
    else
      @form = current_user.forms.find(params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to forms_path, alert: 'Form not found.' }
      format.json { render json: { error: 'Form not found' }, status: :not_found }
    end
  end

  def authorize_form
    authorize @form
  end

  def form_params
    params.require(:form).permit(
      :name, :description, :category, :ai_enabled,
      form_settings: {},
      ai_configuration: {},
      style_configuration: {},
      integration_settings: {}
    )
  end

  def default_form_settings
    {
      form_settings: {
        one_question_per_page: true,
        show_progress_bar: true,
        allow_multiple_submissions: false,
        require_login: false,
        collect_email: true,
        thank_you_message: "Thank you for your response!",
        redirect_url: nil
      }
    }
  end

  def default_ai_configuration
    {
      ai_configuration: {
        version: "1.0",
        enabled_features: [],
        rules_engine: {
          rule_sets: []
        },
        ai_engine: {
          primary_model: "gpt-4o-mini",
          fallback_model: "gpt-3.5-turbo",
          max_tokens: 500,
          temperature: 0.7,
          rate_limiting: {
            max_requests_per_minute: 60,
            max_requests_per_hour: 1000,
            backoff_strategy: "exponential"
          },
          response_validation: {
            enabled: true,
            required_fields: ["question", "type"],
            max_title_length: 100,
            allowed_question_types: ["text", "email", "phone", "number", "multiple_choice", "rating", "date"]
          }
        }
      }
    }
  end

  def handle_form_update(old_ai_config, old_structure)
    # Check if AI configuration changed
    if ai_configuration_changed?(old_ai_config)
      # Regenerate workflow if AI settings changed
      if @form.ai_enabled?
        Forms::WorkflowGenerationJob.perform_async(@form.id)
      end
    end

    # Check if form structure changed
    if form_structure_changed?(old_structure)
      # Update form cache and analytics
      @form.update_form_cache
      
      # Trigger analytics recalculation if form has responses
      if @form.form_responses.any?
        Forms::AnalysisWorkflow.perform_async(@form.id)
      end
    end
  end

  def form_structure_changed?(old_structure)
    current_structure = @form.form_questions.pluck(:id, :position, :question_type)
    old_structure != current_structure
  end

  def ai_configuration_changed?(old_config)
    @form.ai_configuration != old_config
  end

  def download_responses_csv
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      # Headers
      headers = ['ID', 'Completado en', 'Tiempo total (segundos)', 'Direccion IP', 'Agente de usuario']
      
      # Add form question headers
      @form.form_questions.order(:position).each do |question|
        headers << "#{question.title} (#{question.question_type})"
      end
      
      csv << headers
      
      # Data rows
      @responses.each do |response|
        # Calculate total time in seconds
        total_seconds = if response.completed_at && response.started_at
                          (response.completed_at - response.started_at).to_i
                        else
                          0
                        end
        
        row = [
          response.id,
          response.completed_at&.strftime('%Y-%m-%d %H:%M:%S'),
          total_seconds,
          response.ip_address,
          response.user_agent
        ]
        
        # Add form question answers
        @form.form_questions.order(:position).each do |question|
          answer = response.question_responses.find { |qr| qr.form_question_id == question.id }
          if answer
            row << format_answer_value(answer.answer_data['value'])
          else
            row << ''
          end
        end
        
        csv << row
      end
    end
  end

  def format_answer_value(value)
    case value
    when Array
      value.join(', ')
    when Hash
      value.to_json
    when nil
      ''
    else
      value.to_s
    end
  end

  def ai_generation_params
    params.permit(:prompt, :document, :max_questions, :complexity, :authenticity_token)
  end

  # Performs pre-publish validation including payment requirements
  def perform_pre_publish_validation
    # Always run validation service for forms with payment questions
    return unless @form.has_payment_questions?

    Rails.logger.info "Running pre-publish payment validation for form #{@form.id}"
    
    begin
      validation_service = FormPublishValidationService.new(form: @form)
      validation_result = validation_service.call

      # Check if validation service failed or returned negative result
      if validation_service.failure?
        Rails.logger.warn "FormPublishValidationService failed: #{validation_service.errors.full_messages}"
        handle_payment_validation_failure(validation_result.result)
      elsif !validation_result.result[:can_publish]
        Rails.logger.warn "Form cannot be published due to payment validation errors"
        handle_payment_validation_failure(validation_result.result)
      else
        Rails.logger.info "Payment validation passed for form #{@form.id}"
      end
    rescue StandardError => e
      Rails.logger.error "Payment validation service error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Fallback validation if service fails
      perform_fallback_payment_validation
    end
  end

  # Performs fallback payment validation when service fails
  def perform_fallback_payment_validation
    return unless @form&.has_payment_questions?
    
    Rails.logger.info "Performing fallback payment validation for form #{@form.id}"
    
    missing_requirements = []
    
    # Check basic requirements
    missing_requirements << 'stripe_configuration' unless @form.user.stripe_configured?
    missing_requirements << 'premium_subscription' unless @form.user.premium?
    
    # Check payment questions configuration
    payment_questions = @form.form_questions.where(question_type: 'payment')
    if payment_questions.any? { |q| q.question_config.blank? }
      missing_requirements << 'payment_question_configuration'
    end
    
    if missing_requirements.any?
      Rails.logger.warn "Fallback validation found missing requirements: #{missing_requirements}"
      raise PaymentValidationErrors.multiple_requirements(missing_requirements)
    end
  end

  # Handles payment validation failures by raising appropriate errors
  def handle_payment_validation_failure(validation_result)
    errors = validation_result[:validation_errors] || []
    actions = validation_result[:required_actions] || []

    Rails.logger.warn "Payment validation failure - Errors: #{errors.length}, Actions: #{actions.length}"
    
    # Determine the primary error type and create appropriate PaymentValidationError
    if errors.any?
      primary_error = errors.first
      error_type = primary_error[:type]

      Rails.logger.warn "Primary error type: #{error_type}"

      case error_type
      when 'stripe_not_configured'
        raise PaymentValidationErrors.stripe_not_configured(
          additional_actions: actions.map { |a| a[:type] }
        )
      when 'premium_subscription_required'
        raise PaymentValidationErrors.premium_required(
          additional_actions: actions.map { |a| a[:type] }
        )
      when 'payment_acceptance_disabled'
        missing_requirements = []
        missing_requirements << 'stripe_configuration' unless @form.user.stripe_configured?
        missing_requirements << 'premium_subscription' unless @form.user.premium?
        
        raise PaymentValidationErrors.multiple_requirements(
          missing_requirements,
          additional_actions: actions.map { |a| a[:type] }
        )
      when 'payment_question_configuration', 'payment_question_fields'
        raise PaymentValidationErrors.invalid_payment_configuration(
          details: errors.map { |e| e[:description] },
          additional_actions: actions.map { |a| a[:type] }
        )
      else
        # Generic payment validation error with enhanced context
        raise PaymentValidationErrors.custom_error(
          error_type: error_type,
          message: primary_error[:title] || primary_error[:description] || 'Payment validation failed',
          required_actions: actions.map { |a| a[:type] },
          description: primary_error[:description],
          action_url: actions.first&.dig(:action_url),
          action_text: actions.first&.dig(:action_text)
        )
      end
    else
      # Fallback error if no specific errors but validation failed
      Rails.logger.warn "No specific errors found, using fallback error"
      raise PaymentValidationErrors.multiple_requirements(
        ['payment_setup'],
        additional_actions: actions.map { |a| a[:type] }
      )
    end
  end

  # Handles ActiveRecord validation errors during publish
  def handle_publish_validation_error(exception)
    Rails.logger.error "Form publish validation error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    # Check if this is a payment-related validation error
    if exception.message.include?('payment') || exception.message.include?('stripe')
      'Payment configuration is required to publish this form. Please complete your payment setup.'
    elsif exception.message.include?('subscription') || exception.message.include?('premium')
      'A Premium subscription is required to publish forms with payment questions.'
    else
      # Generic validation error
      "Unable to publish form: #{exception.record&.errors&.full_messages&.join(', ') || exception.message}"
    end
  end

  # Override the PaymentErrorHandling concern method for forms-specific behavior
  def handle_payment_error_html(error)
    add_payment_error_context(error)
    
    Rails.logger.info "Handling payment error HTML response for form #{@form&.id}"
    
    # For forms, redirect back to the edit page with payment setup guidance
    redirect_to edit_form_path(@form), 
                alert: error.message,
                flash: { 
                  payment_error: error.to_hash,
                  show_payment_setup: true,
                  payment_error_context: {
                    form_id: @form.id,
                    has_payment_questions: @form.has_payment_questions?,
                    error_type: error.error_type
                  }
                }
  end

  # Override the PaymentErrorHandling concern method for forms-specific Turbo Stream responses
  def handle_payment_error_turbo_stream(error)
    Rails.logger.info "Handling payment error Turbo Stream response for form #{@form&.id}"
    
    # Add payment error context for enhanced guidance
    add_payment_error_context(error)
    
    streams = [
      turbo_stream.replace('flash-messages', 
        partial: 'shared/payment_error_flash', 
        locals: { error: error, context: 'form_publish' }
      ),
      turbo_stream.update('form-status-indicator',
        partial: 'forms/status_indicator',
        locals: { form: @form, error: error }
      )
    ]
    
    # Add form-specific payment guidance
    if @form.present?
      streams << turbo_stream.update('form-publish-section', 
        partial: 'forms/publish_section_with_payment_guidance',
        locals: { form: @form, error: error }
      )
      
      # Show payment setup checklist if available
      streams << turbo_stream.update('payment-setup-checklist',
        partial: 'shared/payment_setup_checklist',
        locals: { 
          user: current_user, 
          error: error, 
          form: @form,
          show_form_context: true 
        }
      )
      
      # Update publish button to show setup required state
      streams << turbo_stream.update('form-publish-button',
        partial: 'forms/publish_button_with_setup_guidance',
        locals: { form: @form, error: error }
      )
    end
    
    # Add payment setup status indicator
    streams << turbo_stream.update('payment-setup-status',
      partial: 'shared/payment_setup_status',
      locals: { user: current_user, error: error, context: 'form_editor' }
    )
    
    render turbo_stream: streams
  end

  # Override the PaymentErrorHandling concern method for forms-specific JSON responses
  def handle_payment_error_json(error)
    Rails.logger.info "Handling payment error JSON response for form #{@form&.id}"
    
    # Build comprehensive error response for API consumers
    error_response = {
      success: false,
      error: error.to_hash,
      context: {
        form_id: @form&.id,
        form_name: @form&.name,
        has_payment_questions: @form&.has_payment_questions?,
        payment_questions_count: @form&.form_questions&.where(question_type: 'payment')&.count || 0,
        user_setup_status: current_user&.payment_setup_status || {},
        validation_timestamp: Time.current.iso8601
      },
      guidance: {
        next_steps: error.required_actions,
        primary_action: {
          url: error.primary_action_url,
          text: error.primary_action_text,
          type: error.required_actions.first
        },
        estimated_setup_time: estimate_setup_time(error),
        help_resources: payment_help_resources
      },
      status: 'payment_validation_failed'
    }
    
    render json: error_response, status: :unprocessable_entity
  end

  # Estimates setup time based on error type and required actions
  def estimate_setup_time(error)
    case error.error_type
    when 'stripe_not_configured'
      '5-10 minutes'
    when 'premium_subscription_required'
      '2-3 minutes'
    when 'multiple_requirements_missing'
      '10-15 minutes'
    when 'invalid_payment_configuration'
      '3-5 minutes'
    else
      '5-10 minutes'
    end
  end

  # Provides help resources for payment setup
  def payment_help_resources
    [
      {
        title: 'Payment Setup Guide',
        url: '/help/payment-setup',
        type: 'documentation'
      },
      {
        title: 'Stripe Integration Tutorial',
        url: '/help/stripe-integration',
        type: 'tutorial'
      },
      {
        title: 'Premium Features Overview',
        url: '/help/premium-features',
        type: 'feature_guide'
      }
    ]
  end
end