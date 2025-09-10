# frozen_string_literal: true

class FormsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_form, only: [:show, :edit, :update, :destroy, :publish, :unpublish, :duplicate, :analytics, :export, :preview, :responses, :download_responses]
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

    # Pagination would be added here with Kaminari gem
    # @forms = @forms.page(params[:page]).per(20)

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
    
    # Track user behavior - page viewed
    Ai::UserBehaviorTrackingService.track_event({
      user_id: current_user.id,
      session_id: session.id,
      event_type: 'page_viewed',
      page_url: request.url,
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    })
    
    # Check if user can use AI features
    unless current_user.can_use_ai_features?
      # Track feature access denied
      Ai::UserBehaviorTrackingService.track_event({
        user_id: current_user.id,
        session_id: session.id,
        event_type: 'error_encountered',
        event_data: { error_type: 'subscription_required', feature: 'ai_form_generation' }
      })
      
      redirect_to new_form_path, alert: 'AI form generation requires a premium subscription.'
      return
    end

    # Check AI credits
    if current_user.ai_credits_remaining <= 0
      # Track credit limit reached
      Ai::UserBehaviorTrackingService.track_event({
        user_id: current_user.id,
        session_id: session.id,
        event_type: 'error_encountered',
        event_data: { error_type: 'credit_limit_exceeded', credits_remaining: 0 }
      })
      
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
  
  # Track form generation started
  Ai::UserBehaviorTrackingService.track_event({
    user_id: current_user.id,
    session_id: session.id,
    event_type: 'form_generation_started',
    event_data: { 
      input_type: params[:document].present? ? 'document' : 'prompt',
      credits_remaining: current_user.ai_credits_remaining
    }
  })
  
  # Check if user can use AI features
  unless current_user.can_use_ai_features?
    # Track feature access denied
    Ai::UserBehaviorTrackingService.track_event({
      user_id: current_user.id,
      session_id: session.id,
      event_type: 'error_encountered',
      event_data: { error_type: 'subscription_required', feature: 'ai_form_generation' }
    })
    
    respond_to do |format|
      format.html { redirect_to new_from_ai_forms_path, alert: 'AI form generation requires a premium subscription.' }
      format.json { render json: { error: 'AI features require a premium subscription' }, status: :forbidden }
    end
    return
  end

  # Check AI credits
  if current_user.ai_credits_remaining <= 0
    # Track credit limit reached
    Ai::UserBehaviorTrackingService.track_event({
      user_id: current_user.id,
      session_id: session.id,
      event_type: 'error_encountered',
      event_data: { error_type: 'credit_limit_exceeded', credits_remaining: 0 }
    })
    
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
  
  # Track input type
  if generation_params[:document].present?
    Ai::UserBehaviorTrackingService.track_event({
      user_id: current_user.id,
      session_id: session.id,
      event_type: 'document_uploaded',
      event_data: { 
        file_size: generation_params[:document].size,
        content_type: generation_params[:document].content_type
      }
    })
  elsif generation_params[:prompt].present?
    Ai::UserBehaviorTrackingService.track_event({
      user_id: current_user.id,
      session_id: session.id,
      event_type: 'prompt_entered',
      event_data: { 
        prompt_length: generation_params[:prompt].length,
        word_count: generation_params[:prompt].split.length
      }
    })
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
      
      # Track successful form generation
      Ai::UserBehaviorTrackingService.track_event({
        user_id: current_user.id,
        session_id: session.id,
        event_type: 'form_generation_completed',
        event_data: { 
          form_id: @form.id,
          questions_count: @form.form_questions.count,
          generation_cost: workflow_result[:generation_cost] || 0.05,
          ai_features_enabled: @form.ai_enabled?
        }
      })
      
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
      # Track failed form generation
      Ai::UserBehaviorTrackingService.track_event({
        user_id: current_user.id,
        session_id: session.id,
        event_type: 'form_generation_failed',
        event_data: { 
          error_type: workflow_result[:error_type] || 'unknown_error',
          error_message: workflow_result[:message] || workflow_result[:error] || 'Unknown error'
        }
      })
      
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
    
    # Track exception during form generation
    Ai::UserBehaviorTrackingService.track_event({
      user_id: current_user.id,
      session_id: session.id,
      event_type: 'form_generation_failed',
      event_data: { 
        error_type: 'exception',
        error_class: e.class.name,
        error_message: e.message
      }
    })
    
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
    if @form.form_questions.any?
      @form.update!(status: 'published', published_at: Time.current)
      
      respond_to do |format|
        format.html { redirect_to @form, notice: 'Form has been published successfully.' }
        format.json { render json: { status: 'published', public_url: @form.public_url } }
      end
    else
      error_message = if @form.ai_enabled?
        'This AI-generated form appears to be incomplete. Please regenerate the form or add questions manually before publishing.'
      else
        'Cannot publish form without questions. Please add at least one question before publishing.'
      end
      
      respond_to do |format|
        format.html { redirect_to edit_form_path(@form), alert: error_message }
        format.json { render json: { error: error_message }, status: :unprocessable_entity }
      end
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

  # POST /forms/:id/test_ai_feature
  def test_ai_feature
    feature_type = params[:feature_type]
    test_data = params[:test_data] || {}

    unless @form.ai_enhanced?
      return render json: { error: 'AI features not enabled for this form' }, status: :unprocessable_entity
    end

    begin
      case feature_type
      when 'response_analysis'
        result = test_response_analysis(test_data)
      when 'dynamic_questions'
        result = test_dynamic_question_generation(test_data)
      when 'sentiment_analysis'
        result = test_sentiment_analysis(test_data)
      else
        return render json: { error: 'Unknown AI feature type' }, status: :bad_request
      end

      render json: { success: true, result: result }
    rescue StandardError => e
      render json: { error: "AI test failed: #{e.message}" }, status: :unprocessable_entity
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

  private



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

  def search_params
    params.permit(:query, :status, :category, :user_id, :commit)
  end

  def sort_params
    params.permit(:sort_by, :sort_direction)
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

  def test_response_analysis(test_data)
    # Create a temporary response for testing
    sample_answer = test_data[:sample_answer] || "This is a test response"
    
    # Use the response processing workflow to analyze
    workflow_result = Forms::ResponseProcessingWorkflow.execute(
      form_id: @form.id,
      test_mode: true,
      sample_data: { answer: sample_answer }
    )
    
    {
      sentiment: workflow_result[:ai_analysis][:sentiment],
      confidence: workflow_result[:ai_analysis][:confidence],
      insights: workflow_result[:ai_analysis][:insights]
    }
  end

  def test_dynamic_question_generation(test_data)
    # Test dynamic question generation
    context_answer = test_data[:context_answer] || "I'm interested in your premium features"
    
    workflow_result = Forms::DynamicQuestionWorkflow.execute(
      form_id: @form.id,
      test_mode: true,
      context_data: { answer: context_answer }
    )
    
    {
      generated_question: workflow_result[:dynamic_question][:title],
      question_type: workflow_result[:dynamic_question][:question_type],
      reasoning: workflow_result[:generation_reasoning]
    }
  end

  def test_sentiment_analysis(test_data)
    # Test sentiment analysis on sample text
    sample_text = test_data[:sample_text] || "I love this product, it's amazing!"
    
    # Use a simple sentiment analysis workflow
    {
      sentiment: analyze_sentiment(sample_text),
      confidence: 0.85,
      keywords: extract_keywords(sample_text)
    }
  end

  def analyze_sentiment(text)
    # Placeholder sentiment analysis - would use actual AI service
    positive_words = %w[love amazing great excellent wonderful fantastic good]
    negative_words = %w[hate terrible awful bad horrible disappointing poor]
    
    positive_count = positive_words.count { |word| text.downcase.include?(word) }
    negative_count = negative_words.count { |word| text.downcase.include?(word) }
    
    if positive_count > negative_count
      'positive'
    elsif negative_count > positive_count
      'negative'
    else
      'neutral'
    end
  end

  def extract_keywords(text)
    # Simple keyword extraction - would use actual NLP service
    words = text.downcase.gsub(/[^\w\s]/, '').split
    stop_words = %w[the a an and or but in on at to for of with by]
    
    (words - stop_words).tally.sort_by { |_, count| -count }.first(5).to_h
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
      
      # Add dynamic question headers
      dynamic_questions_titles = []
      @responses.each do |response|
        response.dynamic_questions.answered.each do |dq|
          title = "Dynamic: #{dq.title}"
          dynamic_questions_titles << title unless dynamic_questions_titles.include?(title)
        end
      end
      dynamic_questions_titles.each { |title| headers << title }
      
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
        
        # Add dynamic question answers
        dynamic_questions_titles.each do |title|
          dynamic_title = title.gsub('Dynamic: ', '')
          dynamic_answer = response.dynamic_questions.answered.find { |dq| dq.title == dynamic_title }
          if dynamic_answer
            row << format_answer_value(dynamic_answer.answer_data['value'])
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
    params.permit(:prompt, :document, :max_questions, :complexity)
  end

  def handle_generation_error(error_data, generation_params)
    @ai_credits_remaining = current_user.ai_credits_remaining
    @estimated_cost = 0.05
    
    # Extract error information
    if error_data.is_a?(Hash)
      error_type = error_data[:error_type] || 'unknown_error'
      error_message = error_data[:message] || error_data[:error] || 'An error occurred'
      retry_count = error_data[:retry_attempts] || 0
      context = error_data.except(:error_type, :message, :error, :retry_attempts)
    else
      error_type = classify_error_from_message(error_data.to_s)
      error_message = error_data.to_s
      retry_count = 0
      context = {}
    end
    
    # Get user-friendly error information
    @error_info = Ai::ErrorMessageService.get_user_friendly_error(error_type, context.merge({
      user: current_user,
      retry_count: retry_count,
      current_url: request.url
    }))
    
    # Get retry plan if applicable
    @retry_plan = Ai::RetryMechanismService.create_retry_plan(error_type, retry_count, context)
    
    # Preserve user input for retry
    @prompt = generation_params[:prompt]
    @max_questions = generation_params[:max_questions]
    @complexity = generation_params[:complexity]
    @document = generation_params[:document]
    
    # Track error recovery attempt
    Ai::UserBehaviorTrackingService.track_event({
      user_id: current_user.id,
      session_id: session.id,
      event_type: 'error_encountered',
      event_data: { 
        error_type: error_type,
        retry_count: retry_count,
        recoverable: @error_info[:recoverable],
        severity: @error_info[:severity]
      }
    })

    respond_to do |format|
      format.html { render :ai_generation_error, status: :unprocessable_entity }
      format.json { 
        render json: { 
          success: false,
          error: @error_info,
          retry_plan: @retry_plan,
          preserved_input: {
            prompt: @prompt,
            max_questions: @max_questions,
            complexity: @complexity
          }
        }, status: :unprocessable_entity 
      }
    end
  end
  
  private

def create_demo_form(generation_params)
  # Create a simple demo form for testing when AI workflow is not available
  begin
    prompt_text = generation_params[:prompt] || "Demo form from document upload"
    
    # Create the form
    form = current_user.forms.create!(
      name: extract_form_name_from_prompt(prompt_text),
      description: "Generated from AI prompt: #{prompt_text.truncate(100)}",
      category: 'survey',
      ai_enabled: true,
      status: 'draft',
      form_settings: default_form_settings[:form_settings],
      ai_configuration: default_ai_configuration[:ai_configuration]
    )
    
    # Create some demo questions based on the prompt
    demo_questions = generate_demo_questions(prompt_text)
    
    demo_questions.each_with_index do |question_data, index|
      form.form_questions.create!(
        title: question_data[:title],
        description: question_data[:description],
        question_type: question_data[:type],
        position: index + 1,
        required: question_data[:required] || false,
        question_config: question_data[:config] || {}
      )
    end
    
    {
      success: true,
      form: form,
      generation_cost: 0.05,
      questions_created: demo_questions.length
    }
    
  rescue StandardError => e
    Rails.logger.error "Failed to create demo form: #{e.message}"
    {
      success: false,
      error_type: 'form_creation_error',
      message: "Failed to create form: #{e.message}"
    }
  end
end

def extract_form_name_from_prompt(prompt)
  # Simple extraction logic - look for keywords that suggest form type
  prompt_lower = prompt.downcase
  
  case prompt_lower
  when /survey|feedback|satisfaction/
    "Customer Feedback Survey"
  when /lead|qualification|sales/
    "Lead Qualification Form"
  when /registration|signup|event/
    "Registration Form"
  when /contact|inquiry|question/
    "Contact Inquiry Form"
  when /application|apply|job/
    "Application Form"
  when /order|purchase|request/
    "Service Request Form"
  else
    "AI Generated Form"
  end
end

def generate_demo_questions(prompt)
  # Generate demo questions based on prompt keywords
  prompt_lower = prompt.downcase
  questions = []
  
  # Always include basic contact info
  questions << {
    title: "What's your name?",
    description: "Please provide your full name",
    type: "text_short",
    required: true,
    config: { max_length: 100 }
  }
  
  questions << {
    title: "What's your email address?",
    description: "We'll use this to contact you",
    type: "email",
    required: true
  }
  
  # Add specific questions based on prompt content
  if prompt_lower.include?('survey') || prompt_lower.include?('feedback')
    questions << {
      title: "How satisfied are you with our service?",
      type: "rating",
      required: true,
      config: { min_value: 1, max_value: 5, labels: { 1 => "Very Dissatisfied", 5 => "Very Satisfied" } }
    }
    
    questions << {
      title: "What could we improve?",
      type: "text_long",
      config: { max_length: 500 }
    }
  end
  
  if prompt_lower.include?('lead') || prompt_lower.include?('business')
    questions << {
      title: "What's your company name?",
      type: "text_short",
      required: true
    }
    
    questions << {
      title: "What's your budget range?",
      type: "single_choice",
      config: { 
        options: ["Under $1,000", "$1,000 - $5,000", "$5,000 - $10,000", "$10,000+"] 
      }
    }
  end
  
  if prompt_lower.include?('event') || prompt_lower.include?('registration')
    questions << {
      title: "How did you hear about this event?",
      type: "single_choice",
      config: { 
        options: ["Social Media", "Email", "Website", "Friend Referral", "Other"] 
      }
    }
    
    questions << {
      title: "Any dietary restrictions?",
      type: "text_short",
      config: { placeholder: "Please specify any dietary needs" }
    }
  end
  
  # Always end with an open feedback question
  questions << {
    title: "Is there anything else you'd like us to know?",
    type: "text_long",
    config: { max_length: 1000, placeholder: "Optional additional comments..." }
  }
  
  questions
end

  def classify_error_from_message(message)
    case message.downcase
    when /monthly ai usage limit exceeded/, /credit.*limit.*exceeded/
      'credit_limit_exceeded'
    when /insufficient.*credit/
      'insufficient_credits'
    when /premium.*subscription/, /subscription.*required/
      'subscription_required'
    when /content too long/
      'content_length_error'
    when /content too short/
      'content_length_error'
    when /unsupported file type/
      'invalid_file_type'
    when /file.*too large/
      'file_too_large'
    when /failed to process document/
      'document_processing_error'
    when /ai.*failed/, /llm.*failed/
      'llm_error'
    when /invalid json/, /json.*parse/
      'json_parse_error'
    when /analysis.*failed/
      'analysis_validation_error'
    when /generation.*failed/
      'generation_validation_error'
    when /timeout/
      'timeout_error'
    when /network/, /connection/
      'network_error'
    when /database/, /save.*failed/
      'database_error'
    else
      'unknown_error'
    end
  end

  def ai_generation_params
    params.permit(:prompt, :document, :max_questions, :complexity)
  end

  def categorize_error_type(error_message)
    case error_message.downcase
    when /monthly.*ai.*usage.*limit.*exceeded/, /credit.*limit.*exceeded/
      'credit_limit_exceeded'
    when /insufficient.*credit/
      'insufficient_credits'
    when /premium.*subscription/, /subscription.*required/
      'subscription_required'
    when /content too long/
      'content_length_error'
    when /content too short/
      'content_length_error'
    when /unsupported file type/
      'invalid_file_type'
    when /file.*too large/
      'file_too_large'
    when /failed to process document/
      'document_processing_error'
    when /ai.*failed/, /llm.*failed/
      'llm_error'
    when /invalid json/, /json.*parse/
      'json_parse_error'
    when /analysis.*failed/
      'analysis_validation_error'
    when /generation.*failed/
      'generation_validation_error'
    when /timeout/
      'timeout_error'
    when /network/, /connection/
      'network_error'
    when /database/, /save.*failed/
      'database_error'
    else
      'unknown_error'
    end
  end
end