# frozen_string_literal: true

module Forms
  class ResponseProcessingWorkflow < ApplicationWorkflow
    workflow do
      # Step 1: Validate and prepare response data
      validate :validate_response_data do
        input :form_response_id, :question_id, :answer_data, :metadata
        description "Validate incoming response data and prepare for processing"
        
        process do |response_id, question_id, answer_data, metadata = {}|
          Rails.logger.info "Validating response data for response_id: #{response_id}, question_id: #{question_id}"
          
          # Validate required inputs
          validate_required_inputs(context, :form_response_id, :question_id, :answer_data)
          
          # Load and validate form response
          form_response = FormResponse.find(response_id)
          unless form_response
            return format_error_result("FormResponse not found", 'not_found_error', { response_id: response_id })
          end
          
          # Load and validate question
          question = FormQuestion.find(question_id)
          unless question
            return format_error_result("FormQuestion not found", 'not_found_error', { question_id: question_id })
          end
          
          # Verify question belongs to the form
          unless question.form_id == form_response.form_id
            return format_error_result("Question does not belong to this form", 'validation_error')
          end
          
          # Validate answer data structure
          validation_errors = validate_response_structure(answer_data)
          if validation_errors.any?
            return format_error_result("Invalid answer data structure", 'validation_error', { errors: validation_errors })
          end
          
          # Validate answer against question type and rules
          question_validation = question.validate_answer(answer_data)
          unless question_validation[:valid]
            return format_error_result("Answer validation failed", 'validation_error', { 
              errors: question_validation[:errors] 
            })
          end
          
          # Calculate response quality metrics
          quality_metrics = calculate_response_quality(question, answer_data)
          
          # Prepare context data for subsequent steps
          context_data = {
            form_response: form_response,
            question: question,
            answer_data: answer_data,
            metadata: metadata.merge({
              validated_at: Time.current.iso8601,
              quality_metrics: quality_metrics,
              session_id: form_response.session_id
            }),
            form_context: get_form_context(form_response.form_id),
            response_context: get_response_context(response_id),
            question_context: get_question_context(question_id)
          }
          
          Rails.logger.info "Response validation successful for question #{question.title}"
          
          format_success_result({
            valid: true,
            form_response: form_response,
            question: question,
            answer_data: answer_data,
            metadata: context_data[:metadata],
            quality_score: quality_metrics[:completeness_score]
          })
        end
      end
      
      # Step 2: Save question response (conditional on validation)
      task :save_question_response do
        input :validate_response_data
        run_when :validate_response_data, ->(result) { result[:valid] }
        description "Save validated response to database"
        
        process do |validation_result|
          Rails.logger.info "Saving question response for question: #{validation_result[:question].title}"
          
          form_response = validation_result[:form_response]
          question = validation_result[:question]
          answer_data = validation_result[:answer_data]
          metadata = validation_result[:metadata]
          
          # Execute database operation safely
          result = safe_db_operation do
            # Find or create question response
            question_response = QuestionResponse.find_or_initialize_by(
              form_response: form_response,
              form_question: question
            )
            
            # Process the answer data using the question's handler
            processed_answer = question.process_answer(answer_data)
            
            # Update question response attributes
            question_response.assign_attributes(
              answer_data: processed_answer,
              response_time_ms: metadata[:response_time_ms],
              skipped: false,
              metadata: metadata.except(:response_time_ms)
            )
            
            # Save the question response
            question_response.save!
            
            # Update form response progress and activity
            form_response.update!(
              last_activity_at: Time.current,
              updated_at: Time.current
            )
            
            # Return success data
            {
              question_response: question_response,
              form_response: form_response,
              processed_answer: processed_answer,
              quality_score: validation_result[:quality_score]
            }
          end
          
          # Handle database operation result
          if result[:error]
            Rails.logger.error "Failed to save question response: #{result[:message]}"
            return format_error_result("Failed to save response", result[:type], result)
          end
          
          Rails.logger.info "Successfully saved question response with ID: #{result[:question_response].id}"
          
          format_success_result({
            question_response_id: result[:question_response].id,
            question_response: result[:question_response],
            form_response: result[:form_response],
            processed_answer: result[:processed_answer],
            quality_score: result[:quality_score],
            saved_at: Time.current.iso8601
          })
        end
      end
      
      # Step 3: AI Enhancement - Analyze response (conditional)
      llm :analyze_response_ai do
        input :save_question_response, :validate_response_data
        run_if do |context|
          validation_result = context.get(:validate_response_data)
          save_result = context.get(:save_question_response)
          
          # Check if validation and save were successful
          return false unless validation_result&.dig(:valid) && save_result&.dig(:success)
          
          question = validation_result[:question]
          form = question.form
          
          # Check if AI analysis is enabled for this question
          return false unless question.ai_enhanced? && question.has_response_analysis?
          
          # Check if form has AI features enabled
          return false unless form.ai_enhanced?
          
          # Check if user has AI credits available
          user = form.user
          return false unless user.can_use_ai_features?
          
          # Check AI budget for this workflow
          estimated_cost = 0.02 # Estimated cost for response analysis
          return false unless ai_budget_available?(context, estimated_cost)
          
          # Check if answer has sufficient content for analysis
          answer_data = validation_result[:answer_data]
          answer_value = answer_data.is_a?(Hash) ? answer_data['value'] : answer_data
          
          # Skip analysis for very short or empty responses
          case question.question_type
          when 'text_short', 'text_long'
            return false if answer_value.to_s.length < 10
          when 'multiple_choice', 'single_choice', 'checkbox'
            # Always analyze choice questions if AI is enabled
            return true
          when 'rating', 'scale', 'nps_score'
            # Analyze ratings if they're below a certain threshold or if configured
            return true
          else
            return false if answer_value.blank?
          end
          
          Rails.logger.info "AI analysis conditions met for question: #{question.title}"
          true
        end
        
        model { |ctx| ctx.get(:validate_response_data)[:question].form.ai_model || 'gpt-4o-mini' }
        temperature 0.3
        max_tokens 500
        response_format :json
        
        system_prompt "You are an AI assistant analyzing form responses for quality, sentiment, and insights."
        
        prompt do |context|
          validation_result = context.get(:validate_response_data)
          save_result = context.get(:save_question_response)
          
          question = validation_result[:question]
          answer_data = validation_result[:answer_data]
          form_context = validation_result[:form_context]
          
          format_ai_analysis_prompt(question, answer_data, form_context)
        end
      end
      
      # Step 4: Update question response with AI analysis
      task :update_with_ai_analysis do
        input :save_question_response, :analyze_response_ai
        run_when :analyze_response_ai
        description "Update response record with AI analysis results"
        
        process do |save_result, ai_analysis|
          Rails.logger.info "Updating question response with AI analysis"
          
          question_response = save_result[:question_response]
          
          # Track AI usage and cost
          ai_cost = 0.02 # Estimated cost for analysis
          track_ai_usage(context, ai_cost, 'response_analysis')
          
          # Execute database update safely
          result = safe_db_operation do
            # Update question response with AI analysis
            question_response.update!(
              ai_analysis_results: ai_analysis,
              ai_analysis_requested_at: Time.current,
              ai_confidence_score: ai_analysis.dig('confidence_score') || 0.0
            )
            
            # Update user's AI credit usage
            user = question_response.form_response.form.user
            user.consume_ai_credit(ai_cost) if user.respond_to?(:consume_ai_credit)
            
            {
              question_response: question_response,
              ai_analysis: ai_analysis,
              ai_cost: ai_cost
            }
          end
          
          if result[:error]
            Rails.logger.error "Failed to update with AI analysis: #{result[:message]}"
            return format_error_result("Failed to save AI analysis", result[:type], result)
          end
          
          Rails.logger.info "Successfully updated question response with AI analysis"
          
          format_success_result({
            question_response_id: result[:question_response].id,
            ai_analysis: result[:ai_analysis],
            ai_cost: result[:ai_cost],
            confidence_score: ai_analysis.dig('confidence_score'),
            sentiment: ai_analysis.dig('sentiment'),
            flags: ai_analysis.dig('flags') || [],
            updated_at: Time.current.iso8601
          })
        end
      end
      
      # Step 5: Generate dynamic follow-up questions (conditional)
      llm :generate_followup_question do
        input :update_with_ai_analysis, :validate_response_data
        run_if do |context|
          validation_result = context.get(:validate_response_data)
          ai_analysis_result = context.get(:update_with_ai_analysis)
          
          # Check if previous steps were successful
          return false unless validation_result&.dig(:valid) && ai_analysis_result&.dig(:success)
          
          question = validation_result[:question]
          answer_data = validation_result[:answer_data]
          ai_analysis = ai_analysis_result[:ai_analysis]
          
          # Check if question is configured to generate follow-ups
          return false unless question.generates_followups?
          
          # Check AI budget for follow-up generation
          estimated_cost = 0.015 # Estimated cost for follow-up generation
          return false unless ai_budget_available?(context, estimated_cost)
          
          # Use helper method to determine if follow-up should be generated
          should_generate = should_generate_followup?(question, answer_data, ai_analysis)
          
          Rails.logger.info "Follow-up generation conditions: #{should_generate ? 'met' : 'not met'} for question: #{question.title}"
          should_generate
        end
        
        model { |ctx| ctx.get(:validate_response_data)[:question].form.ai_model || 'gpt-4o-mini' }
        temperature 0.7
        max_tokens 300
        response_format :json
        
        system_prompt "You are an expert at generating contextual follow-up questions based on user responses."
        
        prompt do |context|
          validation_result = context.get(:validate_response_data)
          ai_analysis_result = context.get(:update_with_ai_analysis)
          
          question = validation_result[:question]
          answer_data = validation_result[:answer_data]
          form_context = validation_result[:form_context]
          ai_analysis = ai_analysis_result[:ai_analysis]
          
          # Get previous responses for context
          form_response = validation_result[:form_response]
          previous_responses = form_response.answers_hash
          
          format_followup_prompt(question, answer_data, form_context, previous_responses, ai_analysis)
        end
      end
      
      # Step 6: Create dynamic question record
      task :create_dynamic_question do
        input :generate_followup_question, :validate_response_data
        run_when :generate_followup_question
        description "Create and persist dynamic question record"
        
        process do |followup_data, validation_result|
          Rails.logger.info "Creating dynamic question from AI-generated follow-up"
          
          form_response = validation_result[:form_response]
          source_question = validation_result[:question]
          
          # Track AI usage for follow-up generation
          ai_cost = 0.015
          track_ai_usage(context, ai_cost, 'followup_generation')
          
          # Execute database operation safely
          result = safe_db_operation do
            # Extract question data from AI response
            question_data = followup_data.dig('question') || {}
            
            # Create dynamic question record
            dynamic_question = DynamicQuestion.create!(
              form_response: form_response,
              generated_from_question: source_question,
              question_type: question_data['question_type'] || 'text_short',
              title: question_data['title'],
              description: question_data['description'],
              configuration: question_data['configuration'] || {},
              generation_context: {
                source_question_id: source_question.id,
                source_answer: validation_result[:answer_data],
                reasoning: followup_data['reasoning'],
                confidence: followup_data['confidence'],
                priority: followup_data['priority'],
                generated_at: Time.current.iso8601
              },
              generation_prompt: "AI-generated follow-up based on response analysis",
              generation_model: source_question.form.ai_model || 'gpt-4o-mini',
              ai_confidence: followup_data['confidence'] || 0.8
            )
            
            # Update user's AI credit usage
            user = form_response.form.user
            user.consume_ai_credit(ai_cost) if user.respond_to?(:consume_ai_credit)
            
            {
              dynamic_question: dynamic_question,
              followup_data: followup_data,
              ai_cost: ai_cost
            }
          end
          
          if result[:error]
            Rails.logger.error "Failed to create dynamic question: #{result[:message]}"
            return format_error_result("Failed to create dynamic question", result[:type], result)
          end
          
          Rails.logger.info "Successfully created dynamic question with ID: #{result[:dynamic_question].id}"
          
          format_success_result({
            dynamic_question_id: result[:dynamic_question].id,
            dynamic_question: result[:dynamic_question],
            followup_data: result[:followup_data],
            ai_cost: result[:ai_cost],
            created_at: Time.current.iso8601
          })
        end
      end
      
      # Step 7: Real-time UI update via Turbo Streams
      stream :update_form_ui do
        input :save_question_response, :create_dynamic_question
        description "Update form UI in real-time with new content"
        
        target { |ctx| "form_#{ctx.get(:validate_response_data)[:form_response].form.share_token}" }
        turbo_action :append
        partial "responses/question_response"
        
        locals do |ctx|
          validation_result = ctx.get(:validate_response_data)
          save_result = ctx.get(:save_question_response)
          dynamic_question_result = ctx.get(:create_dynamic_question)
          
          form_response = validation_result[:form_response]
          question_response = save_result[:question_response]
          
          locals_hash = {
            form_response: form_response,
            question_response: question_response,
            form: form_response.form,
            progress_percentage: form_response.progress_percentage
          }
          
          # Add dynamic question if it was created
          if dynamic_question_result&.dig(:success)
            locals_hash[:dynamic_question] = dynamic_question_result[:dynamic_question]
            locals_hash[:show_dynamic_question] = true
          end
          
          locals_hash
        end
      end
    end
    
    private
    
    # Helper methods will be implemented in subsequent subtasks
    def validate_response_structure(answer_data)
      errors = []
      
      # Check if answer_data is present
      if answer_data.nil?
        errors << "Answer data cannot be nil"
        return errors
      end
      
      # Ensure answer_data is a hash or can be converted to one
      unless answer_data.is_a?(Hash) || answer_data.is_a?(String) || answer_data.is_a?(Array) || answer_data.is_a?(Numeric)
        errors << "Answer data must be a valid data type (Hash, String, Array, or Numeric)"
      end
      
      # If it's a hash, validate required structure
      if answer_data.is_a?(Hash)
        # Check for suspicious or malicious content
        if answer_data.to_s.length > 50000 # 50KB limit
          errors << "Answer data is too large"
        end
        
        # Validate nested structure depth (prevent deeply nested attacks)
        if answer_data.to_s.count('{') > 10
          errors << "Answer data structure is too deeply nested"
        end
      end
      
      errors
    end
    
    def calculate_response_quality(question, answer_data)
      quality_metrics = {
        completeness_score: 0.0,
        response_length: 0,
        has_content: false,
        estimated_effort: 'low'
      }
      
      # Extract the actual answer value
      answer_value = answer_data.is_a?(Hash) ? answer_data['value'] : answer_data
      
      # Check if answer has content
      quality_metrics[:has_content] = !answer_value.blank?
      
      return quality_metrics unless quality_metrics[:has_content]
      
      # Calculate completeness based on question type
      case question.question_type
      when 'text_short', 'text_long'
        text_length = answer_value.to_s.length
        quality_metrics[:response_length] = text_length
        
        if text_length >= 50
          quality_metrics[:completeness_score] = 1.0
          quality_metrics[:estimated_effort] = 'high'
        elsif text_length >= 20
          quality_metrics[:completeness_score] = 0.8
          quality_metrics[:estimated_effort] = 'medium'
        elsif text_length >= 5
          quality_metrics[:completeness_score] = 0.6
          quality_metrics[:estimated_effort] = 'low'
        else
          quality_metrics[:completeness_score] = 0.3
        end
        
      when 'multiple_choice', 'single_choice', 'checkbox'
        # Choice questions get full score for any selection
        quality_metrics[:completeness_score] = 1.0
        quality_metrics[:estimated_effort] = 'medium'
        
      when 'rating', 'scale', 'nps_score'
        # Rating questions get full score
        quality_metrics[:completeness_score] = 1.0
        quality_metrics[:estimated_effort] = 'low'
        
      when 'email'
        # Validate email format for quality
        if answer_value.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
          quality_metrics[:completeness_score] = 1.0
          quality_metrics[:estimated_effort] = 'medium'
        else
          quality_metrics[:completeness_score] = 0.3
        end
        
      when 'phone'
        # Basic phone validation
        clean_phone = answer_value.to_s.gsub(/[^\d+]/, '')
        if clean_phone.length >= 10
          quality_metrics[:completeness_score] = 1.0
          quality_metrics[:estimated_effort] = 'medium'
        else
          quality_metrics[:completeness_score] = 0.5
        end
        
      else
        # Default scoring for other question types
        quality_metrics[:completeness_score] = 0.8
        quality_metrics[:estimated_effort] = 'medium'
      end
      
      quality_metrics
    end
    
    def should_generate_followup?(question, answer_data, ai_analysis)
      # Check AI analysis for follow-up indicators
      if ai_analysis.dig('insights')&.any? { |insight| insight['type'] == 'followup_suggested' }
        return true
      end
      
      # Check confidence score - generate follow-up for low confidence responses
      confidence_score = ai_analysis.dig('confidence_score') || 1.0
      return true if confidence_score < 0.7
      
      # Check for specific question types and answer patterns
      answer_value = answer_data.is_a?(Hash) ? answer_data['value'] : answer_data
      
      case question.question_type
      when 'rating', 'scale', 'nps_score'
        # Generate follow-up for low ratings
        rating_value = answer_value.to_f
        max_rating = question.rating_config[:max] || 5
        return true if rating_value <= (max_rating * 0.6) # Below 60% of max rating
        
      when 'multiple_choice', 'single_choice'
        # Generate follow-up for "Other" selections or specific choices
        return true if answer_value.to_s.downcase.include?('other')
        
      when 'text_short', 'text_long'
        # Generate follow-up for responses that indicate issues or concerns
        negative_keywords = ['problem', 'issue', 'difficult', 'confusing', 'unclear', 'frustrated']
        return true if negative_keywords.any? { |keyword| answer_value.to_s.downcase.include?(keyword) }
      end
      
      false
    end
    
    def format_ai_analysis_prompt(question, answer_data, form_context)
      answer_value = answer_data.is_a?(Hash) ? answer_data['value'] : answer_data
      
      <<~PROMPT
        Analyze the following form response and provide insights in JSON format.

        **Form Context:**
        - Form Name: #{form_context[:form_name]}
        - Form Category: #{form_context[:form_category]}
        - Total Questions: #{form_context[:questions_count]}

        **Question Details:**
        - Question: "#{question.title}"
        - Type: #{question.question_type}
        - Required: #{question.required?}
        - Description: #{question.description || 'None'}

        **User Response:**
        "#{answer_value}"

        **Analysis Required:**
        Please analyze this response and return a JSON object with the following structure:

        {
          "sentiment": "positive|neutral|negative|very_positive|very_negative",
          "confidence_score": 0.0-1.0,
          "quality_indicators": {
            "completeness": 0.0-1.0,
            "relevance": 0.0-1.0,
            "clarity": 0.0-1.0
          },
          "insights": [
            {
              "type": "sentiment|quality|content|behavioral",
              "description": "Brief insight description",
              "confidence": 0.0-1.0
            }
          ],
          "flags": [
            {
              "type": "spam|inappropriate|incomplete|suspicious",
              "reason": "Explanation of the flag",
              "severity": "low|medium|high"
            }
          ],
          "keywords": ["extracted", "key", "terms"],
          "summary": "Brief summary of the response analysis"
        }

        **Guidelines:**
        - Be objective and professional in your analysis
        - Consider the question type when evaluating response quality
        - Flag any potentially problematic content
        - Extract meaningful keywords and themes
        - Provide actionable insights for form optimization
      PROMPT
    end
    
    def format_followup_prompt(question, answer_data, form_context, previous_responses, ai_analysis = {})
      answer_value = answer_data.is_a?(Hash) ? answer_data['value'] : answer_data
      
      <<~PROMPT
        Generate a contextual follow-up question based on the user's response.

        **Form Context:**
        - Form Name: #{form_context[:form_name]}
        - Form Category: #{form_context[:form_category]}
        - Purpose: #{form_context[:settings]&.dig('purpose') || 'General information collection'}

        **Original Question:**
        - Question: "#{question.title}"
        - Type: #{question.question_type}
        - Description: #{question.description || 'None'}

        **User's Response:**
        "#{answer_value}"

        **AI Analysis:**
        - Sentiment: #{ai_analysis.dig('sentiment') || 'neutral'}
        - Confidence: #{ai_analysis.dig('confidence_score') || 'unknown'}
        - Key Insights: #{ai_analysis.dig('insights')&.map { |i| i['description'] }&.join(', ') || 'None'}

        **Previous Responses Context:**
        #{previous_responses.map { |q, a| "- #{q}: #{a}" }.join("\n")}

        **Instructions:**
        Generate a natural, conversational follow-up question that:
        1. Builds on their response to gather more valuable information
        2. Feels like a natural conversation, not an interrogation
        3. Is relevant to the form's purpose and context
        4. Helps qualify or better understand their needs/situation
        5. Is concise and easy to answer

        **Response Format (JSON):**
        {
          "question": {
            "title": "The follow-up question text",
            "description": "Optional helpful description or context",
            "question_type": "text_short|text_long|multiple_choice|rating|yes_no",
            "configuration": {
              // Type-specific configuration (options for choice questions, scale for ratings, etc.)
            },
            "required": false
          },
          "reasoning": "Brief explanation of why this follow-up adds value",
          "confidence": 0.0-1.0,
          "priority": "high|medium|low"
        }

        **Guidelines:**
        - Keep questions conversational and natural
        - Avoid repetitive or obvious questions
        - Focus on gathering actionable insights
        - Consider the user's emotional state from their response
        - Make the question feel valuable, not burdensome
      PROMPT
    end
  end
end