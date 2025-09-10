# frozen_string_literal: true

class Api::V1::ResponsesController < Api::BaseController
  before_action :set_form, only: [:index, :show, :create, :update, :destroy, :analytics, :export]
  before_action :set_response, only: [:show, :update, :destroy, :resume, :abandon, :submit_answer, :complete, :answers]
  before_action :authorize_form_access, only: [:index, :show, :create, :update, :destroy, :analytics, :export]

  # GET /api/v1/forms/:form_id/responses
  def index
    authorize_token!('responses', 'read') || return

    @responses = policy_scope(@form.form_responses)
                        .includes(:question_responses)
                        .order(created_at: :desc)

    # Apply filters
    apply_response_filters

    # Apply sorting
    apply_response_sorting

    # Pagination
    @responses = paginate_collection(@responses)

    render json: {
      success: true,
      data: {
        responses: serialize_responses(@responses),
        pagination: pagination_meta(@responses),
        summary: response_summary_stats
      }
    }
  end

  # GET /api/v1/responses/:id
  def show
    authorize_token!('responses', 'read') || return

    render json: {
      success: true,
      data: {
        response: serialize_response(@response, include_answers: true, include_analytics: true)
      }
    }
  end

  # POST /api/v1/forms/:form_id/responses
  def create
    authorize_token!('responses', 'write') || return

    @response = @form.form_responses.build(response_params)
    @response.session_id = generate_api_session_id
    @response.ip_address = request.remote_ip
    @response.user_agent = request.user_agent

    if @response.save
      render_created(
        { response: serialize_response(@response) },
        message: 'Response created successfully'
      )
    else
      render_unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/responses/:id
  def update
    authorize_token!('responses', 'write') || return

    if @response.update(response_params)
      render_updated(
        { response: serialize_response(@response) },
        message: 'Response updated successfully'
      )
    else
      render_unprocessable_entity
    end
  end

  # DELETE /api/v1/responses/:id
  def destroy
    authorize_token!('responses', 'delete') || return

    @response.destroy!

    render_deleted(message: 'Response deleted successfully')
  end

  # POST /api/v1/responses/:id/submit_answer
  def submit_answer
    authorize_token!('responses', 'write') || return

    @question = find_question_by_id(params[:question_id])
    
    unless @question
      return render json: {
        success: false,
        error: 'Question not found',
        code: 'QUESTION_NOT_FOUND'
      }, status: :not_found
    end

    # Process the answer submission
    result = process_answer_submission(@question)

    if result[:success]
      render json: {
        success: true,
        data: {
          question_response: serialize_question_response(result[:question_response]),
          next_question: result[:next_question] ? serialize_question(result[:next_question]) : nil,
          progress: @response.progress_percentage,
          completed: result[:completed] || false
        }
      }
    else
      render json: {
        success: false,
        error: 'Answer submission failed',
        errors: result[:errors],
        code: 'ANSWER_VALIDATION_ERROR'
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/responses/:id/complete
  def complete
    authorize_token!('responses', 'write') || return

    unless @response.can_be_completed?
      return render json: {
        success: false,
        error: 'Response cannot be completed',
        message: 'Not all required questions have been answered',
        code: 'INCOMPLETE_RESPONSE'
      }, status: :unprocessable_entity
    end

    completion_data = {
      completed_at: Time.current,
      completion_method: 'api',
      api_token_id: current_api_token.id
    }

    if @response.mark_completed!(completion_data)
      render json: {
        success: true,
        message: 'Response completed successfully',
        data: {
          response: serialize_response(@response),
          completion_data: completion_data
        }
      }
    else
      render json: {
        success: false,
        error: 'Failed to complete response',
        code: 'COMPLETION_ERROR'
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/responses/:id/abandon
  def abandon
    authorize_token!('responses', 'write') || return

    abandonment_reason = params[:reason] || 'api_abandoned'
    
    @response.mark_abandoned!(abandonment_reason)

    render json: {
      success: true,
      message: 'Response marked as abandoned',
      data: {
        response: serialize_response(@response)
      }
    }
  end

  # POST /api/v1/responses/:id/resume
  def resume
    authorize_token!('responses', 'write') || return

    unless @response.paused?
      return render json: {
        success: false,
        error: 'Response is not paused',
        message: 'Only paused responses can be resumed',
        code: 'INVALID_STATUS'
      }, status: :unprocessable_entity
    end

    if @response.resume!
      render json: {
        success: true,
        message: 'Response resumed successfully',
        data: {
          response: serialize_response(@response),
          next_question: serialize_question(@response.next_question)
        }
      }
    else
      render json: {
        success: false,
        error: 'Failed to resume response',
        code: 'RESUME_ERROR'
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/forms/:form_id/responses/analytics
  def analytics
    authorize_token!('responses', 'read') || return

    analytics_period = params[:period]&.to_i&.days || 30.days
    
    analytics_data = {
      summary: calculate_response_analytics(analytics_period),
      trends: calculate_response_trends(analytics_period),
      completion_funnel: calculate_completion_funnel,
      question_analytics: calculate_question_analytics(analytics_period)
    }

    render json: {
      success: true,
      data: analytics_data
    }
  end

  # GET /api/v1/forms/:form_id/responses/export
  def export
    authorize_token!('responses', 'read') || return

    export_format = params[:format] || 'csv'
    export_options = {
      format: export_format,
      include_metadata: params[:include_metadata] == 'true',
      date_range: params[:date_range],
      status_filter: params[:status]
    }

    begin
      export_data = generate_response_export(export_options)
      
      render json: {
        success: true,
        data: {
          download_url: export_data[:download_url],
          filename: export_data[:filename],
          expires_at: export_data[:expires_at],
          format: export_format,
          record_count: export_data[:record_count]
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

  # GET /api/v1/responses/:id/answers
  def answers
    authorize_token!('responses', 'read') || return

    answers = @response.question_responses
                      .includes(:form_question)
                      .order('form_questions.position')

    render json: {
      success: true,
      data: {
        answers: serialize_question_responses(answers),
        response_summary: @response.response_summary
      }
    }
  end

  private

  def set_form
    @form = current_user.forms.find(params[:form_id])
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def set_response
    if params[:form_id] && @form
      @response = @form.form_responses.find(params[:id])
    else
      @response = FormResponse.joins(:form)
                             .where(forms: { user: current_user })
                             .find(params[:id])
      @form = @response.form if @response
    end
  rescue ActiveRecord::RecordNotFound
    render_not_found
  end

  def authorize_form_access
    authorize @form
  rescue Pundit::NotAuthorizedError
    render_unauthorized
  end

  def response_params
    params.require(:response).permit(
      :status, :referrer_url, :draft_data,
      utm_parameters: {}, metadata: {}
    )
  end

  def answer_params
    params.require(:answer).permit(:value, :started_at, :completed_at, metadata: {})
  end

  def generate_api_session_id
    "api_#{current_api_token.id}_#{SecureRandom.hex(16)}_#{Time.current.to_i}"
  end

  def find_question_by_id(question_id)
    @form.form_questions.find_by(id: question_id)
  end

  def process_answer_submission(question)
    answer_data = extract_answer_data
    
    # Validate the answer
    validation_result = validate_answer_data(question, answer_data)
    return validation_result unless validation_result[:valid]

    # Create or update question response
    question_response = @response.question_responses
                                .find_or_initialize_by(form_question: question)
    
    question_response.assign_attributes(
      answer_data: answer_data,
      response_time_ms: calculate_response_time(answer_data)
    )

    if question_response.save
      # Update response activity
      @response.touch(:last_activity_at)

      # Find next question
      next_question = find_next_question

      # Check if response should be completed
      completed = next_question.nil? && @response.can_be_completed?
      
      if completed
        @response.mark_completed!({
          completed_at: Time.current,
          completion_method: 'api_auto',
          api_token_id: current_api_token.id
        })
      end

      {
        success: true,
        question_response: question_response,
        next_question: next_question,
        completed: completed
      }
    else
      {
        success: false,
        errors: question_response.errors.full_messages
      }
    end
  end

  def extract_answer_data
    answer_data = answer_params.to_h
    
    # Add API-specific metadata
    answer_data[:metadata] ||= {}
    answer_data[:metadata][:submitted_via] = 'api'
    answer_data[:metadata][:api_token_id] = current_api_token.id
    answer_data[:metadata][:ip_address] = request.remote_ip
    answer_data[:metadata][:user_agent] = request.user_agent
    
    answer_data
  end

  def validate_answer_data(question, answer_data)
    # Basic validation
    if question.required? && answer_data[:value].blank?
      return { valid: false, errors: ['Answer is required'] }
    end

    # Type-specific validation would go here
    # For now, return valid
    { valid: true }
  end

  def calculate_response_time(answer_data)
    return 0 unless answer_data[:started_at] && answer_data[:completed_at]

    started = Time.parse(answer_data[:started_at])
    completed = Time.parse(answer_data[:completed_at])
    ((completed - started) * 1000).to_i
  rescue
    0
  end

  def find_next_question
    answered_question_ids = @response.question_responses
                                   .joins(:form_question)
                                   .pluck('form_questions.id')
    
    @form.form_questions
         .where.not(id: answered_question_ids)
         .order(:position)
         .first
  end

  def apply_response_filters
    # Status filter
    if params[:status].present? && FormResponse.statuses.key?(params[:status])
      @responses = @responses.where(status: params[:status])
    end

    # Date range filter
    if params[:start_date].present?
      start_date = Date.parse(params[:start_date])
      @responses = @responses.where('form_responses.created_at >= ?', start_date)
    end

    if params[:end_date].present?
      end_date = Date.parse(params[:end_date])
      @responses = @responses.where('form_responses.created_at <= ?', end_date.end_of_day)
    end

    # Quality score filter
    if params[:min_quality_score].present?
      @responses = @responses.where('quality_score >= ?', params[:min_quality_score].to_f)
    end
  end

  def apply_response_sorting
    case params[:sort_by]
    when 'created_at'
      @responses = @responses.order(created_at: params[:sort_direction] == 'asc' ? :asc : :desc)
    when 'completed_at'
      @responses = @responses.order(completed_at: params[:sort_direction] == 'asc' ? :asc : :desc)
    when 'progress'
      # This would require a calculated field or subquery
      @responses = @responses.order(created_at: :desc)
    when 'quality_score'
      @responses = @responses.order(quality_score: params[:sort_direction] == 'asc' ? :asc : :desc)
    else
      @responses = @responses.order(created_at: :desc)
    end
  end

  def response_summary_stats
    {
      total_responses: @form.form_responses.count,
      completed_responses: @form.form_responses.completed.count,
      in_progress_responses: @form.form_responses.in_progress.count,
      abandoned_responses: @form.form_responses.abandoned.count,
      completion_rate: @form.cached_completion_rate || 0.0,
      average_completion_time: calculate_average_completion_time
    }
  end

  def calculate_average_completion_time
    completed_responses = @form.form_responses.completed
                               .where.not(started_at: nil, completed_at: nil)
    
    return 0.0 if completed_responses.empty?

    total_time = completed_responses.sum do |response|
      next 0 unless response.started_at && response.completed_at
      (response.completed_at - response.started_at) / 60.0 # in minutes
    end

    (total_time / completed_responses.count).round(2)
  end

  def calculate_response_analytics(period)
    responses = @form.form_responses.where('created_at >= ?', period.ago)
    
    {
      total_responses: responses.count,
      completed_responses: responses.completed.count,
      completion_rate: responses.count > 0 ? (responses.completed.count.to_f / responses.count * 100).round(2) : 0.0,
      average_completion_time: calculate_period_completion_time(responses.completed),
      abandonment_rate: responses.count > 0 ? (responses.abandoned.count.to_f / responses.count * 100).round(2) : 0.0
    }
  end

  def calculate_response_trends(period)
    # This would typically involve grouping by date and calculating daily metrics
    # For now, return a simple structure
    []
  end

  def calculate_completion_funnel
    questions = @form.form_questions.order(:position)
    funnel_data = []

    questions.each_with_index do |question, index|
      responses_reached = @form.form_responses
                               .joins(:question_responses)
                               .where(question_responses: { form_question: question })
                               .distinct
                               .count

      funnel_data << {
        step: index + 1,
        question_title: question.title,
        responses_reached: responses_reached,
        drop_off_rate: index > 0 ? calculate_drop_off_rate(funnel_data[index - 1][:responses_reached], responses_reached) : 0.0
      }
    end

    funnel_data
  end

  def calculate_drop_off_rate(previous_count, current_count)
    return 0.0 if previous_count.zero?
    
    ((previous_count - current_count).to_f / previous_count * 100).round(2)
  end

  def calculate_question_analytics(period)
    @form.form_questions.includes(:question_responses).map do |question|
      responses = question.question_responses
                         .joins(:form_response)
                         .where('form_responses.created_at >= ?', period.ago)

      {
        question_id: question.id,
        question_title: question.title,
        question_type: question.question_type,
        total_responses: responses.count,
        average_response_time: responses.average(:response_time_ms) || 0,
        skip_rate: calculate_question_skip_rate(question, period)
      }
    end
  end

  def calculate_question_skip_rate(question, period)
    total_reached = @form.form_responses
                         .where('created_at >= ?', period.ago)
                         .joins(:question_responses)
                         .where('form_questions.position <= ?', question.position)
                         .distinct
                         .count

    answered = question.question_responses
                      .joins(:form_response)
                      .where('form_responses.created_at >= ?', period.ago)
                      .where.not(answer_data: {})
                      .count

    return 0.0 if total_reached.zero?
    
    ((total_reached - answered).to_f / total_reached * 100).round(2)
  end

  def calculate_period_completion_time(responses)
    return 0.0 if responses.empty?

    total_time = responses.sum do |response|
      next 0 unless response.started_at && response.completed_at
      (response.completed_at - response.started_at) / 60.0
    end

    (total_time / responses.count).round(2)
  end

  def generate_response_export(options)
    # This would typically generate a file and return a download URL
    # For now, return mock data
    {
      download_url: "https://example.com/exports/responses_#{SecureRandom.hex(8)}.#{options[:format]}",
      filename: "form_#{@form.id}_responses_#{Date.current.strftime('%Y%m%d')}.#{options[:format]}",
      expires_at: 24.hours.from_now,
      record_count: @form.form_responses.count
    }
  end

  # Serialization Methods
  def serialize_responses(responses)
    responses.map { |response| serialize_response(response) }
  end

  def serialize_response(response, include_answers: false, include_analytics: false)
    result = {
      id: response.id,
      form_id: response.form_id,
      session_id: response.session_id,
      status: response.status,
      progress_percentage: response.progress_percentage,
      started_at: response.started_at,
      completed_at: response.completed_at,
      last_activity_at: response.last_activity_at,
      duration_minutes: response.duration_minutes,
      quality_score: response.quality_score,
      sentiment_score: response.sentiment_score,
      ip_address: response.ip_address,
      user_agent: response.user_agent,
      referrer_url: response.referrer_url,
      utm_parameters: response.utm_parameters,
      created_at: response.created_at,
      updated_at: response.updated_at
    }

    if include_answers
      result[:answers] = serialize_question_responses(response.question_responses.includes(:form_question))
    end

    if include_analytics
      result[:analytics] = {
        quality_score: response.quality_score,
        sentiment_score: response.sentiment_score,
        duration_minutes: response.duration_minutes,
        progress_percentage: response.progress_percentage
      }
    end

    result
  end

  def serialize_question_responses(question_responses)
    question_responses.map { |qr| serialize_question_response(qr) }
  end

  def serialize_question_response(question_response)
    {
      id: question_response.id,
      question_id: question_response.form_question_id,
      question_title: question_response.form_question.title,
      question_type: question_response.form_question.question_type,
      answer_data: question_response.answer_data,
      formatted_answer: question_response.formatted_answer,
      response_time_ms: question_response.response_time_ms,
      skipped: question_response.skipped?,
      ai_confidence_score: question_response.ai_confidence_score,
      created_at: question_response.created_at,
      updated_at: question_response.updated_at
    }
  end

  def serialize_question(question)
    return nil unless question
    
    {
      id: question.id,
      title: question.title,
      description: question.description,
      question_type: question.question_type,
      position: question.position,
      required: question.required?,
      options: question.options,
      validation_rules: question.validation_rules
    }
  end
end