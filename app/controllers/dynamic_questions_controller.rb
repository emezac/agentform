class DynamicQuestionsController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :verify_authenticity_token
  skip_after_action :verify_authorized, unless: :skip_authorization?
  skip_after_action :verify_policy_scoped, unless: :skip_authorization?

  def answer
    Rails.logger.info "=== Procesando respuesta de pregunta dinámica ==="
    
    # Find form by share token
    form = Form.find_by!(share_token: params[:share_token])
    
    # Find the form response
    form_response = form.form_responses.find_by!(session_id: current_session_id)
    
    # Find the dynamic question
    dynamic_question = form_response.dynamic_questions.find(params[:id])
    
    answer_value = params.require(:answer).permit(:value)[:value]
    
    Rails.logger.info "Question ID: #{dynamic_question.id}"
    Rails.logger.info "Answer: '#{answer_value}'"

    if answer_value.present?
      # Update the dynamic question with the answer
      update_attributes = { 
        answer_data: { 
          value: answer_value,
          submitted_at: Time.current.iso8601
        }
      }
      
      # Add answered_at if the column exists
      if dynamic_question.respond_to?(:answered_at=)
        update_attributes[:answered_at] = Time.current
      end
      
      dynamic_question.update!(update_attributes)
      
      Rails.logger.info "✓ Respuesta guardada exitosamente"
      
      # Create a visual success message and remove the form
      success_html = render_to_string(
        partial: 'responses/dynamic_question_success',
        locals: {
          dynamic_question: dynamic_question,
          answer_value: answer_value
        }
      )
      
      # Update the UI via Turbo Stream
      Turbo::StreamsChannel.broadcast_replace_to(
        form_response,
        target: "dynamic_question_#{dynamic_question.id}",
        html: success_html
      )
      
      # Store the dynamic question response for later access
      store_dynamic_response_in_session(dynamic_question, answer_value)
      
      respond_to do |format|
        format.turbo_stream do
          # This will automatically replace the target with the success partial
          render turbo_stream: turbo_stream.replace(
            "dynamic_question_#{dynamic_question.id}",
            partial: 'responses/dynamic_question_success',
            locals: { dynamic_question: dynamic_question, answer_value: answer_value }
          )
        end
        format.json do
          render json: { 
            success: true, 
            message: "¡Gracias por tu respuesta!",
            question_id: dynamic_question.id,
            ui_updated: true
          }
        end
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "dynamic_question_#{dynamic_question.id}",
            partial: 'responses/dynamic_question_error',
            locals: { dynamic_question: dynamic_question, errors: ["La respuesta no puede estar vacía"] }
          )
        end
        format.json do
          render json: { 
            success: false, 
            errors: ["La respuesta no puede estar vacía"] 
          }, status: :unprocessable_content
        end
      end
    end
    
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Dynamic question not found: #{e.message}"
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "dynamic_question_#{params[:id]}",
          partial: 'responses/dynamic_question_error',
          locals: { errors: ["Pregunta no encontrada"] }
        )
      end
      format.json do
        render json: { 
          success: false, 
          errors: ["Pregunta no encontrada"] 
        }, status: :not_found
      end
    end
    
  rescue => e
    Rails.logger.error "Error guardando respuesta de pregunta dinámica: #{e.message}"
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "dynamic_question_#{params[:id]}",
          partial: 'responses/dynamic_question_error',
          locals: { errors: ["Ocurrió un error al guardar tu respuesta"] }
        )
      end
      format.json do
        render json: { 
          success: false, 
          errors: ["Ocurrió un error al guardar tu respuesta"] 
        }, status: :unprocessable_content
      end
    end
  end

  private

  def current_session_id
    session[:form_session_id] || 
    request.headers['X-Session-Id'] ||
    cookies[:form_session_id]
  end

  def store_dynamic_response_in_session(dynamic_question, answer_value)
    # Store the dynamic question response so it can be accessed later
    session[:dynamic_responses] ||= {}
    session[:dynamic_responses][dynamic_question.id] = {
      question_title: dynamic_question.title,
      answer: answer_value,
      answered_at: Time.current.iso8601,
      trigger: dynamic_question.generation_context['trigger']
    }
    
    Rails.logger.info "Respuesta dinámica guardada en sesión"
  end

  def skip_authorization?
    true
  end
end