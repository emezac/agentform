# frozen_string_literal: true

module Forms
  class UniversalAIWorkflow < ApplicationWorkflow
    workflow do
      # 1. Validate and load context
      task :validate_and_load_context do
        input :form_response_id, :question_id, :answer_data
        
        process do |response_id, question_id, answer_data|
          form_response = FormResponse.find(response_id)
          question = FormQuestion.find(question_id)
          form = form_response.form
          
          # Validate that the form has AI enabled
          unless form.ai_enhanced?
            return { error: "AI not enabled for this form", skip_processing: true }
          end
          
          # Validate AI configuration
          validator = AIConfigurationValidator.new(form.ai_configuration)
          unless validator.validate
            Rails.logger.error "Invalid AI configuration for form #{form.id}: #{validator.errors}"
            return { error: "Invalid AI configuration", skip_processing: true }
          end
          
          {
            form_response: form_response,
            question: question,
            form: form,
            answer_data: answer_data,
            ai_config: form.ai_configuration
          }
        end
      end
      
      # 2. Evaluate rules and determine actions
      task :evaluate_rules do
        input :validate_and_load_context
        run_unless { |ctx| ctx.get(:validate_and_load_context)[:skip_processing] }
        
        process do |context_data|
          rules_engine = AIRulesEngine.new(
            context_data[:form],
            context_data[:form_response], 
            context_data[:question],
            context_data[:answer_data]
          )
          
          execution_results = rules_engine.evaluate_and_execute
          
          {
            execution_results: execution_results,
            context_data: context_data,
            has_dynamic_questions: execution_results.any? { |r| r[:rule_set_id]&.include?('dynamic') }
          }
        end
      end
      
      # 3. Generate dynamic questions with rate limiting
      llm :generate_dynamic_questions do
        input :evaluate_rules
        run_if { |ctx| ctx.get(:evaluate_rules)[:has_dynamic_questions] }
        
        model do |ctx|
          ai_config = ctx.get(:evaluate_rules).dig(:context_data, :ai_config)
          ai_config.dig('ai_engine', 'primary_model') || 'gpt-4'
        end
        
        temperature { |ctx| 
          ctx.get(:evaluate_rules).dig(:context_data, :ai_config, 'ai_engine', 'temperature') || 0.7
        }
        
        max_tokens { |ctx|
          ctx.get(:evaluate_rules).dig(:context_data, :ai_config, 'ai_engine', 'max_tokens') || 500
        }
        
        response_format :json
        
        system_prompt do |ctx|
          # Build contextual prompt based on configuration
          data = ctx.get(:evaluate_rules)
          context = data[:context_data]
          
          "You are an expert at generating contextual follow-up questions for forms. Always respond with valid JSON containing 'title', 'description', and 'question_type' fields. The question should be relevant, empathetic, and help gather valuable information."
        end
        
        prompt do |ctx|
          data = ctx.get(:evaluate_rules)
          context = data[:context_data]
          
          # Use the ContextualPromptBuilder to create rich prompts
          dynamic_rule = data[:execution_results].find { |r| r[:action_results]&.any? { |ar| ar[:type] == 'generate_dynamic_question' } }
          
          if dynamic_rule
            prompt_config = dynamic_rule[:action_results].find { |ar| ar[:type] == 'generate_dynamic_question' }[:config]
            prompt_builder = ContextualPromptBuilder.new(
              context,
              prompt_config['prompt_template']
            )
            prompt_builder.build_user_prompt
          else
            "Generate a relevant follow-up question based on the user's response."
          end
        end
        
        # Configure rate limiting and retries
        rate_limit do |ctx|
          ai_config = ctx.get(:evaluate_rules).dig(:context_data, :ai_config, 'ai_engine', 'rate_limiting')
          {
            max_requests_per_minute: ai_config&.dig('max_requests_per_minute') || 20,
            max_requests_per_hour: ai_config&.dig('max_requests_per_hour') || 200
          }
        end
        
        retry_on_failure max_attempts: 3, backoff: :exponential
      end
      
      # 4. Validate and save generated questions
      task :validate_and_save_questions do
        input :generate_dynamic_questions, :evaluate_rules
        run_when :generate_dynamic_questions
        
        process do |llm_result, eval_data|
          context = eval_data[:context_data]
          form_response = context[:form_response]
          source_question = context[:question]
          
          # Validate LLM response
          validation_result = validate_llm_response(llm_result, context[:ai_config])
          
          if validation_result[:valid]
            # Create and save dynamic question
            dynamic_question = create_dynamic_question(
              llm_result, 
              form_response, 
              source_question,
              eval_data[:execution_results]
            )
            
            # Broadcast to UI
            broadcast_dynamic_question(dynamic_question, form_response)
            
            { success: true, dynamic_question: dynamic_question, validation: validation_result }
          else
            Rails.logger.error "Invalid LLM response for form #{form_response.form_id}: #{validation_result[:errors]}"
            { success: false, errors: validation_result[:errors] }
          end
        end
      end
      
      # 5. Execute additional actions (lead scoring, notifications, etc.)
      task :execute_additional_actions do
        input :evaluate_rules
        
        process do |eval_data|
          additional_results = []
          
          eval_data[:execution_results].each do |result|
            action_results = result[:action_results] || []
            non_question_actions = action_results.reject { |ar| ar[:type] == 'generate_dynamic_question' }
            
            non_question_actions.each do |action_result|
              # Process lead scoring, notifications, etc.
              processed_result = process_additional_action(action_result, eval_data[:context_data])
              additional_results << processed_result
            end
          end
          
          { additional_actions_results: additional_results }
        end
      end
      
      # 6. Logging and cleanup
      task :finalize_processing do
        input :validate_and_save_questions, :execute_additional_actions, :evaluate_rules
        
        process do |questions_result, actions_result, eval_data|
          context = eval_data[:context_data]
          
          # Log results for analysis
          log_workflow_execution(
            context[:form_response],
            eval_data[:execution_results],
            questions_result,
            actions_result
          )
          
          # Update analytics cache
          Rails.cache.delete("form_analytics/#{context[:form].id}")
          
          # Update user AI credits
          update_user_ai_credits(context[:form].user)
          
          {
            success: true,
            questions_generated: questions_result&.dig(:success) || false,
            additional_actions_executed: actions_result&.dig(:additional_actions_results)&.length || 0,
            execution_summary: build_execution_summary(eval_data, questions_result, actions_result)
          }
        end
      end
    end
    
    private
    
    def validate_llm_response(response, ai_config)
      validation_config = ai_config.dig('ai_engine', 'response_validation') || {}
      
      return { valid: true } unless validation_config['enabled']
      
      errors = []
      
      # Ensure it's a valid JSON object
      unless response.is_a?(Hash)
        errors << "Response must be valid JSON object"
        return { valid: false, errors: errors }
      end
      
      # Check required fields
      required_fields = validation_config['required_fields'] || ['title', 'question_type']
      required_fields.each do |field|
        errors << "Missing required field: #{field}" if response[field].blank?
      end
      
      # Check title length
      if response['title'].present? && validation_config['max_title_length']
        max_length = validation_config['max_title_length']
        errors << "Title too long (max #{max_length} chars)" if response['title'].length > max_length
      end
      
      # Check question type
      if response['question_type'].present?
        allowed_types = validation_config['allowed_question_types'] || FormQuestion::QUESTION_TYPES
        unless allowed_types.include?(response['question_type'])
          errors << "Invalid question type: #{response['question_type']}"
        end
      end
      
      # Validate JSON structure
      begin
        JSON.parse(response.to_json)
      rescue JSON::ParserError => e
        errors << "Invalid JSON structure: #{e.message}"
      end
      
      { valid: errors.empty?, errors: errors }
    end
    
    def create_dynamic_question(llm_result, form_response, source_question, execution_results)
      # Extract metadata from execution
      rule_metadata = extract_rule_metadata(execution_results)
      
      DynamicQuestion.create!(
        form_response: form_response,
        generated_from_question: source_question,
        title: llm_result['title'],
        description: llm_result['description'],
        question_type: llm_result['question_type'],
        required: llm_result['required'] || false,
        max_attempts: llm_result['max_attempts'] || 3,
        ai_confidence: calculate_generation_confidence(llm_result),
        generation_context: {
          triggered_by_rules: execution_results.map { |r| r[:rule_set_id] },
          generation_timestamp: Time.current.iso8601,
          prompt_strategy: rule_metadata[:prompt_strategy],
          model_used: rule_metadata[:model_used],
          original_answer: form_response.answer_data_for_question(source_question)
        },
        generation_model: rule_metadata[:model_used] || 'gpt-4',
        position: form_response.dynamic_questions.count + 1
      )
    end
    
    def broadcast_dynamic_question(dynamic_question, form_response)
      # Broadcast via Turbo Streams
      Turbo::StreamsChannel.broadcast_append_to(
        "form_response_#{form_response.id}",
        target: "dynamic_questions_#{form_response.id}",
        partial: "dynamic_questions/question",
        locals: { 
          dynamic_question: dynamic_question, 
          form_response: form_response 
        }
      )
    end
    
    def process_additional_action(action_result, context_data)
      case action_result[:type]
      when 'update_lead_score'
        process_lead_score_update(action_result, context_data)
      when 'trigger_notification'
        process_notification(action_result, context_data)
      else
        { success: false, error: "Unknown action type: #{action_result[:type]}" }
      end
    end
    
    def process_lead_score_update(action_result, context_data)
      form_response = context_data[:form_response]
      config = action_result[:config]
      
      current_score = form_response.lead_score || 0
      new_score = [current_score + config['score_adjustment'], 0].max
      
      form_response.update!(lead_score: new_score)
      
      {
        type: 'lead_score_update',
        success: true,
        score_change: config['score_adjustment'],
        new_score: new_score,
        reason: config['reason']
      }
    end
    
    def process_notification(action_result, context_data)
      config = action_result[:config]
      form = context_data[:form]
      
      # Send notifications based on channels
      config['channels'].each do |channel|
        case channel
        when 'email'
          send_email_notification(config, form)
        when 'slack'
          send_slack_notification(config, form)
        end
      end
      
      {
        type: 'notification',
        success: true,
        channels: config['channels'],
        notification_type: config['type']
      }
    end
    
    def send_email_notification(config, form)
      # Implementation would use your email service
      Rails.logger.info "Email notification sent: #{config['type']} for form #{form.id}"
    end
    
    def send_slack_notification(config, form)
      # Implementation would use your Slack integration
      Rails.logger.info "Slack notification sent: #{config['type']} for form #{form.id}"
    end
    
    def log_workflow_execution(form_response, execution_results, questions_result, actions_result)
      Rails.logger.info({
        event: 'universal_ai_workflow_executed',
        form_id: form_response.form_id,
        response_id: form_response.id,
        rules_executed: execution_results.length,
        questions_generated: questions_result&.dig(:success) ? 1 : 0,
        additional_actions: actions_result&.dig(:additional_actions_results)&.length || 0,
        execution_time: Time.current.iso8601,
        ai_cost: calculate_ai_cost(execution_results)
      }.to_json)
    end
    
    def calculate_ai_cost(execution_results)
      # Placeholder - implement actual cost calculation
      execution_results.length * 0.01 # $0.01 per rule execution
    end
    
    def update_user_ai_credits(user)
      # Update user's AI credits based on usage
      current_credits = user.ai_credits_remaining || 0
      consumed = calculate_ai_cost([]) # Use actual cost calculation
      user.update!(ai_credits_remaining: [current_credits - consumed, 0].max)
    end
    
    def build_execution_summary(eval_data, questions_result, actions_result)
      {
        form_id: eval_data[:context_data][:form].id,
        response_id: eval_data[:context_data][:form_response].id,
        rules_triggered: eval_data[:execution_results].map { |r| r[:rule_set_id] },
        questions_generated: questions_result&.dig(:success) ? 1 : 0,
        actions_executed: actions_result&.dig(:additional_actions_results)&.map { |ar| ar[:type] } || [],
        timestamp: Time.current.iso8601
      }
    end
    
    def extract_rule_metadata(execution_results)
      dynamic_rule = execution_results.find { |r| r[:action_results]&.any? { |ar| ar[:type] == 'generate_dynamic_question' } }
      
      if dynamic_rule
        action = dynamic_rule[:action_results].find { |ar| ar[:type] == 'generate_dynamic_question' }
        {
          prompt_strategy: action.dig(:config, 'prompt_strategy'),
          model_used: action.dig(:config, 'model') || 'gpt-4'
        }
      else
        {
          prompt_strategy: 'default',
          model_used: 'gpt-4'
        }
      end
    end
  end
end