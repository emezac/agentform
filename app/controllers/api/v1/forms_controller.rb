# frozen_string_literal: true

class Api::V1::FormsController < Api::BaseController
  before_action :set_form, only: [:show, :update, :destroy, :publish, :unpublish, :duplicate, :analytics, :export, :preview, :test_ai_feature, :embed_code]
  before_action :authorize_form_access, only: [:show, :update, :destroy, :publish, :unpublish, :duplicate, :analytics, :export, :preview, :test_ai_feature, :embed_code]

  # GET /api/v1/forms
  def index
    authorize_token!('forms', 'read') || return

    @forms = policy_scope(Form)
                        .includes(:form_questions, :form_responses)
                        .order(created_at: :desc)

    # Apply search filter
    if search_params[:query].present?
      @forms = @forms.where("name ILIKE ? OR description ILIKE ?", 
                           "%#{search_params[:query]}%", 
                           "%#{search_params[:query]}%")
    end

    # Apply status filter
    if search_params[:status].present? && Form.statuses.key?(search_params[:status])
      @forms = @forms.where(status: search_params[:status])
    end

    # Apply category filter
    if search_params[:category].present? && Form.categories.key?(search_params[:category])
      @forms = @forms.where(category: search_params[:category])
    end

    # Apply sorting
    case sort_params[:sort_by]
    when 'name'
      @forms = @forms.order(:name)
    when 'responses'
      @forms = @forms.order(:responses_count)
    when 'completion_rate'
      @forms = @forms.order(:completions_count)
    else
      @forms = @forms.order(created_at: :desc)
    end

    # Pagination
    @forms = paginate_collection(@forms)

    render json: {
      success: true,
      data: {
        forms: serialize_forms(@forms),
        pagination: pagination_meta(@forms)
      }
    }
  end

  # GET /api/v1/forms/:id
  def show
    authorize_token!('forms', 'read') || return

    render json: {
      success: true,
      data: {
        form: serialize_form(@form, include_questions: true, include_analytics: true)
      }
    }
  end

  # POST /api/v1/forms
  def create
    authorize_token!('forms', 'write') || return

    @form = current_user.forms.build(form_params)
    authorize @form
    
    @form.assign_attributes(default_form_settings) if @form.form_settings.blank?
    @form.assign_attributes(default_ai_configuration) if @form.ai_configuration.blank?

    if @form.save
      # Trigger workflow generation if AI is enabled
      if @form.ai_enabled?
        Forms::WorkflowGenerationJob.perform_later(@form.id)
      end

      render_created(
        { form: serialize_form(@form) },
        message: 'Form created successfully'
      )
    else
      render_unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/forms/:id
  def update
    authorize_token!('forms', 'write') || return

    old_ai_config = @form.ai_configuration.dup
    old_structure = @form.form_questions.pluck(:id, :position, :question_type)

    if @form.update(form_params)
      handle_form_update(old_ai_config, old_structure)

      render_updated(
        { form: serialize_form(@form) },
        message: 'Form updated successfully'
      )
    else
      render_unprocessable_entity
    end
  end

  # DELETE /api/v1/forms/:id
  def destroy
    authorize_token!('forms', 'delete') || return

    @form.destroy!

    render_deleted(message: 'Form deleted successfully')
  end

  # POST /api/v1/forms/:id/publish
  def publish
    authorize_token!('forms', 'write') || return

    unless @form.form_questions.any?
      return render json: {
        success: false,
        error: 'Cannot publish form without questions',
        code: 'FORM_VALIDATION_ERROR'
      }, status: :unprocessable_entity
    end

    @form.update!(status: 'published', published_at: Time.current)
    
    render json: {
      success: true,
      message: 'Form published successfully',
      data: {
        form: serialize_form(@form),
        public_url: @form.public_url
      }
    }
  end

  # POST /api/v1/forms/:id/unpublish
  def unpublish
    authorize_token!('forms', 'write') || return

    @form.update!(status: 'draft', published_at: nil)
    
    render json: {
      success: true,
      message: 'Form unpublished successfully',
      data: {
        form: serialize_form(@form)
      }
    }
  end

  # POST /api/v1/forms/:id/duplicate
  def duplicate
    authorize_token!('forms', 'write') || return

    begin
      duplicated_form = Forms::ManagementAgent.new.duplicate_form(@form, current_user, {
        name: "#{@form.name} (Copy)",
        status: 'draft'
      })

      render_created(
        { form: serialize_form(duplicated_form) },
        message: 'Form duplicated successfully'
      )
    rescue StandardError => e
      render json: {
        success: false,
        error: 'Duplication failed',
        message: e.message,
        code: 'DUPLICATION_ERROR'
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/forms/:id/analytics
  def analytics
    authorize_token!('forms', 'read') || return

    analytics_period = params[:period]&.to_i&.days || 30.days
    analytics_data = @form.cached_analytics_summary(period: analytics_period)
    
    question_analytics = @form.form_questions.includes(:question_responses)
                              .map { |q| [q.id, q.analytics_summary(analytics_period)] }
                              .to_h

    response_trends = @form.form_analytics
                           .for_period(analytics_period.ago.to_date, Date.current)
                           .where(period_type: 'daily')
                           .order(:date)

    render json: {
      success: true,
      data: {
        summary: analytics_data,
        questions: question_analytics,
        trends: serialize_analytics_trends(response_trends),
        period: analytics_period.to_i
      }
    }
  end

  # GET /api/v1/forms/:id/export
  def export
    authorize_token!('forms', 'read') || return

    export_format = params[:format] || 'csv'
    export_options = {
      format: export_format,
      include_metadata: params[:include_metadata] == 'true',
      date_range: params[:date_range]
    }

    begin
      export_data = Forms::ManagementAgent.new.export_form_data(@form, export_options)
      
      render json: {
        success: true,
        data: {
          download_url: export_data[:download_url],
          filename: export_data[:filename],
          expires_at: export_data[:expires_at],
          format: export_format
        }
      }
    rescue StandardError => e
      render json: {
        success: false,
        error: 'Export failed',
        message: e.message,
        code: 'EXPORT_ERROR'
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/forms/:id/preview
  def preview
    authorize_token!('forms', 'read') || return

    render json: {
      success: true,
      data: {
        form: serialize_form(@form, include_questions: true),
        preview_url: Rails.application.routes.url_helpers.public_form_preview_url(@form.share_token)
      }
    }
  end

  # POST /api/v1/forms/:id/test_ai_feature
  def test_ai_feature
    authorize_token!('forms', 'write') || return

    feature_type = params[:feature_type]
    test_data = params[:test_data] || {}

    unless @form.ai_enhanced?
      return render json: {
        success: false,
        error: 'AI features not enabled',
        message: 'AI features are not enabled for this form',
        code: 'AI_NOT_ENABLED'
      }, status: :unprocessable_entity
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
        return render json: {
          success: false,
          error: 'Unknown AI feature type',
          message: "Feature type '#{feature_type}' is not supported",
          code: 'INVALID_FEATURE_TYPE'
        }, status: :bad_request
      end

      render json: {
        success: true,
        data: {
          feature_type: feature_type,
          result: result
        }
      }
    rescue StandardError => e
      render json: {
        success: false,
        error: 'AI test failed',
        message: e.message,
        code: 'AI_TEST_ERROR'
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/forms/:id/embed_code
  def embed_code
    authorize_token!('forms', 'read') || return

    width = params[:width] || '100%'
    height = params[:height] || '600px'
    
    render json: {
      success: true,
      data: {
        embed_code: @form.embed_code(width: width, height: height),
        public_url: @form.public_url,
        share_token: @form.share_token
      }
    }
  end

  # GET /api/v1/forms/templates
  def templates
    authorize_token!('forms', 'read') || return

    # This will be implemented when FormTemplate model is fully developed
    templates = [] # FormTemplate.public_templates.featured
    
    render json: {
      success: true,
      data: {
        templates: templates
      }
    }
  end

  private

  def set_form
    @form = Form.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def authorize_form_access
    authorize @form
  rescue Pundit::NotAuthorizedError
    render_unauthorized
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
    params.permit(:query, :status, :category)
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
        enabled: false,
        features: [],
        model: 'gpt-4o-mini',
        temperature: 0.7,
        max_tokens: 500,
        confidence_threshold: 0.7
      }
    }
  end

  def handle_form_update(old_ai_config, old_structure)
    # Check if AI configuration changed
    if ai_configuration_changed?(old_ai_config)
      # Regenerate workflow if AI settings changed
      if @form.ai_enabled?
        Forms::WorkflowGenerationJob.perform_later(@form.id)
      end
    end

    # Check if form structure changed
    if form_structure_changed?(old_structure)
      # Update form cache and analytics
      @form.update_form_cache
      
      # Trigger analytics recalculation if form has responses
      if @form.form_responses.any?
        # TODO: Fix this to use the correct workflow execution method
        # Forms::AnalysisWorkflow.execute(@form.id)
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

  # AI Testing Methods
  def test_response_analysis(test_data)
    sample_answer = test_data[:sample_answer] || "This is a test response"
    
    # For now, return mock data since SuperAgent workflows are not fully implemented
    {
      sentiment: analyze_sentiment(sample_answer),
      confidence: 0.85,
      insights: ["Sample analysis for: #{sample_answer}"]
    }
  end

  def test_dynamic_question_generation(test_data)
    _context_answer = test_data[:context_answer] || "I'm interested in your premium features"
    
    # For now, return mock data since SuperAgent workflows are not fully implemented
    {
      generated_question: "What specific features are you most interested in?",
      question_type: "multiple_choice",
      reasoning: "Generated follow-up based on interest in premium features"
    }
  end

  def test_sentiment_analysis(test_data)
    sample_text = test_data[:sample_text] || "I love this product, it's amazing!"
    
    {
      sentiment: analyze_sentiment(sample_text),
      confidence: 0.85,
      keywords: extract_keywords(sample_text)
    }
  end

  def analyze_sentiment(text)
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
    words = text.downcase.gsub(/[^\w\s]/, '').split
    stop_words = %w[the a an and or but in on at to for of with by]
    
    (words - stop_words).tally.sort_by { |_, count| -count }.first(5).to_h
  end

  # Serialization Methods
  def serialize_forms(forms)
    forms.map { |form| serialize_form(form) }
  end

  def serialize_form(form, include_questions: false, include_analytics: false)
    result = {
      id: form.id,
      name: form.name,
      description: form.description,
      status: form.status,
      category: form.category,
      share_token: form.share_token,
      public_url: form.public_url,
      ai_enabled: form.ai_enabled?,
      ai_enhanced: form.ai_enhanced?,
      created_at: form.created_at,
      updated_at: form.updated_at,
      published_at: form.published_at,
      form_settings: form.form_settings,
      ai_configuration: form.ai_configuration,
      style_configuration: form.style_configuration,
      integration_settings: form.integration_settings,
      questions_count: form.form_questions.count,
      responses_count: form.responses_count || 0,
      completion_rate: form.cached_completion_rate
    }

    if include_questions
      result[:questions] = form.form_questions.order(:position).map do |question|
        serialize_question(question)
      end
    end

    if include_analytics
      result[:analytics] = form.cached_analytics_summary
    end

    result
  end

  def serialize_question(question)
    {
      id: question.id,
      title: question.title,
      description: question.description,
      question_type: question.question_type,
      position: question.position,
      required: question.required?,
      ai_enhanced: question.ai_enhanced?,
      options: question.options,
      validation_rules: question.validation_rules,
      conditional_logic: question.conditional_logic,
      created_at: question.created_at,
      updated_at: question.updated_at
    }
  end

  def serialize_analytics_trends(trends)
    trends.map do |trend|
      {
        date: trend.date,
        period_type: trend.period_type,
        views_count: trend.views_count,
        started_responses_count: trend.started_responses_count,
        completed_responses_count: trend.completed_responses_count,
        completion_rate: trend.completion_rate,
        conversion_rate: trend.conversion_rate
      }
    end
  end
end