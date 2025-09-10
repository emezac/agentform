# frozen_string_literal: true

module Forms
  class DynamicQuestionWorkflow < ApplicationWorkflow
    workflow do
      # Step 1: Validate context and determine if dynamic question should be generated
      validate :validate_generation_context do
        input :form_response_id, :source_question_id, :source_answer_data, :generation_trigger
        description "Validate context and determine if dynamic question generation is appropriate"
        
        process do |response_id, question_id, answer_data, trigger = 'ai_analysis'|
          Rails.logger.info "Validating dynamic question generation context for response_id: #{response_id}, question_id: #{question_id}"
          
          # Validate required inputs
          validate_required_inputs(context, :form_response_id, :source_question_id, :source_answer_data)
          
          # Load and validate form response
          form_response = FormResponse.find(response_id)
          unless form_response
            return format_error_result("FormResponse not found", 'not_found_error', { response_id: response_id })
          end
          
          # Load and validate source question
          source_question = FormQuestion.find(question_id)
          unless source_question
            return format_error_result("FormQuestion not found", 'not_found_error', { question_id: question_id })
          end
          
          # Verify question belongs to the form
          unless source_question.form_id == form_response.form_id
            return format_error_result("Question does not belong to this form", 'validation_error')
          end
          
          # Check if form and question support dynamic questions
          form = source_question.form
          unless form.ai_enhanced?
            return format_error_result("Form does not have AI features enabled", 'configuration_error')
          end
          
          unless source_question.generates_followups?
            return format_error_result("Source question is not configured for follow-ups", 'configuration_error')
          end
          
          # Check user's AI capabilities
          user = form.user
          unless user.can_use_ai_features?
            return format_error_result("User does not have AI features available", 'permission_error')
          end
          
          # Check if we've already generated too many dynamic questions for this response
          existing_dynamic_questions = form_response.dynamic_questions.count
          max_dynamic_questions = form.ai_configuration&.dig('max_dynamic_questions') || 3
          
          if existing_dynamic_questions >= max_dynamic_questions
            return format_error_result("Maximum dynamic questions limit reached", 'limit_error', {
              existing_count: existing_dynamic_questions,
              max_allowed: max_dynamic_questions
            })
          end
          
          # Prepare context data for generation
          context_data = {
            form_response: form_response,
            source_question: source_question,
            form: form,
            user: user,
            answer_data: answer_data,
            generation_trigger: trigger,
            existing_dynamic_count: existing_dynamic_questions,
            form_context: get_form_context(form.id),
            response_context: get_response_context(response_id),
            previous_responses: form_response.answers_hash
          }
          
          Rails.logger.info "Dynamic question generation context validated successfully"
          
          format_success_result({
            valid: true,
            context_data: context_data,
            can_generate: true,
            estimated_cost: 0.025 # Estimated cost for dynamic question generation
          })
        end
      end      

      # Step 2: Analyze source answer to determine follow-up strategy
      task :analyze_followup_strategy do
        input :validate_generation_context
        description "Analyze the source answer to determine the best follow-up strategy"
        
        process do |validation_result|
          Rails.logger.info "Analyzing follow-up strategy for dynamic question generation"
          
          context_data = validation_result[:context_data]
          source_question = context_data[:source_question]
          answer_data = context_data[:answer_data]
          previous_responses = context_data[:previous_responses]
          
          # Analyze the answer to determine follow-up strategy
          strategy = determine_followup_strategy(source_question, answer_data, previous_responses)
          
          # Calculate priority and confidence for generation
          generation_priority = calculate_generation_priority(source_question, answer_data, strategy)
          
          # Determine question type for the follow-up
          suggested_question_type = suggest_question_type(source_question, answer_data, strategy)
          
          # Check if strategy suggests generation should proceed
          unless strategy[:should_generate]
            return format_success_result({
              should_generate: false,
              reason: strategy[:skip_reason],
              strategy: strategy
            })
          end
          
          Rails.logger.info "Follow-up strategy determined: #{strategy[:type]} with priority #{generation_priority}"
          
          format_success_result({
            should_generate: true,
            strategy: strategy,
            generation_priority: generation_priority,
            suggested_question_type: suggested_question_type,
            context_data: context_data
          })
        end
      end
      
      # Step 3: Generate dynamic question using LLM
      llm :generate_dynamic_question do
        input :analyze_followup_strategy, :validate_generation_context
        run_if do |context|
          strategy_result = context.get(:analyze_followup_strategy)
          validation_result = context.get(:validate_generation_context)
          
          # Check if previous steps were successful
          return false unless validation_result&.dig(:valid) && strategy_result&.dig(:should_generate)
          
          # Check AI budget
          estimated_cost = validation_result[:estimated_cost]
          return false unless ai_budget_available?(context, estimated_cost)
          
          Rails.logger.info "LLM generation conditions met for dynamic question"
          true
        end
        
        model { |ctx| 
          validation_result = ctx.get(:validate_generation_context)
          validation_result[:context_data][:form].ai_model || 'gpt-4o-mini' 
        }
        temperature 0.7
        max_tokens 400
        response_format :json
        
        system_prompt "You are an expert at generating contextual follow-up questions that feel natural and gather valuable information. Create questions that enhance the conversation flow and provide actionable insights."
        
        prompt do |context|
          validation_result = context.get(:validate_generation_context)
          strategy_result = context.get(:analyze_followup_strategy)
          
          context_data = validation_result[:context_data]
          strategy = strategy_result[:strategy]
          suggested_type = strategy_result[:suggested_question_type]
          
          format_dynamic_question_prompt(context_data, strategy, suggested_type)
        end
      end   
   
      # Step 4: Create and persist dynamic question record
      task :create_dynamic_question_record do
        input :generate_dynamic_question, :validate_generation_context, :analyze_followup_strategy
        run_when :generate_dynamic_question
        description "Create and persist the dynamic question record in the database"
        
        process do |llm_result, validation_result, strategy_result|
          Rails.logger.info "Creating dynamic question record from LLM generation"
          
          context_data = validation_result[:context_data]
          form_response = context_data[:form_response]
          source_question = context_data[:source_question]
          strategy = strategy_result[:strategy]
          
          # Track AI usage
          ai_cost = validation_result[:estimated_cost]
          track_ai_usage(context, ai_cost, 'dynamic_question_generation')
          
          # Execute database operation safely
          result = safe_db_operation do
            # Extract question data from LLM response
            question_data = llm_result.dig('question') || {}
            
            # Validate LLM response structure
            unless question_data['title'].present?
              raise ArgumentError, "LLM did not provide a valid question title"
            end
            
            # Create dynamic question record
            dynamic_question = DynamicQuestion.create!(
              form_response: form_response,
              generated_from_question: source_question,
              question_type: question_data['question_type'] || strategy_result[:suggested_question_type] || 'text_short',
              title: question_data['title'],
              description: question_data['description'],
              configuration: question_data['configuration'] || {},
              generation_context: {
                source_question_id: source_question.id,
                source_answer: context_data[:answer_data],
                strategy_type: strategy[:type],
                strategy_reasoning: strategy[:reasoning],
                llm_reasoning: llm_result['reasoning'],
                confidence: llm_result['confidence'],
                priority: strategy_result[:generation_priority],
                generation_trigger: context_data[:generation_trigger],
                generated_at: Time.current.iso8601,
                form_context_snapshot: context_data[:previous_responses]
              },
              generation_prompt: "AI-generated follow-up based on #{strategy[:type]} strategy",
              generation_model: context_data[:form].ai_model || 'gpt-4o-mini',
              ai_confidence: llm_result['confidence'] || 0.8
            )
            
            # Update user's AI credit usage
            user = context_data[:user]
            user.consume_ai_credit(ai_cost) if user.respond_to?(:consume_ai_credit)
            
            {
              dynamic_question: dynamic_question,
              llm_result: llm_result,
              ai_cost: ai_cost,
              strategy: strategy
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
            llm_result: result[:llm_result],
            ai_cost: result[:ai_cost],
            strategy: result[:strategy],
            created_at: Time.current.iso8601
          })
        end
      end
      
      # Step 5: Update form UI with new dynamic question
      stream :update_form_with_dynamic_question do
        input :create_dynamic_question_record, :validate_generation_context
        description "Update the form UI in real-time with the new dynamic question"
        
        target { |ctx| 
          validation_result = ctx.get(:validate_generation_context)
          form = validation_result[:context_data][:form]
          "form_#{form.share_token}_dynamic_questions" 
        }
        turbo_action :append
        partial "responses/dynamic_question"
        
        locals do |ctx|
          validation_result = ctx.get(:validate_generation_context)
          creation_result = ctx.get(:create_dynamic_question_record)
          
          {
            dynamic_question: creation_result[:dynamic_question],
            form_response: validation_result[:context_data][:form_response],
            form: validation_result[:context_data][:form],
            source_question: validation_result[:context_data][:source_question],
            generation_metadata: {
              strategy: creation_result[:strategy],
              ai_confidence: creation_result[:dynamic_question].ai_confidence,
              created_at: creation_result[:created_at]
            }
          }
        end
      end
    end    
 
   private
    
    # Determine the best follow-up strategy based on the source question and answer
    def determine_followup_strategy(source_question, answer_data, previous_responses)
      answer_value = answer_data.is_a?(Hash) ? answer_data['value'] : answer_data
      
      # Default strategy
      strategy = {
        type: 'general_followup',
        should_generate: true,
        reasoning: 'Standard follow-up generation',
        confidence: 0.6
      }
      
      # Analyze based on question type
      case source_question.question_type
      when 'rating', 'scale', 'nps_score'
        rating_value = answer_value.to_f
        max_rating = source_question.question_config&.dig('max_value') || 5
        
        if rating_value <= (max_rating * 0.4) # Low rating (40% or below)
          strategy = {
            type: 'low_rating_investigation',
            should_generate: true,
            reasoning: "Low rating (#{rating_value}/#{max_rating}) suggests issues that need investigation",
            confidence: 0.9,
            focus: 'problem_identification'
          }
        elsif rating_value >= (max_rating * 0.8) # High rating (80% or above)
          strategy = {
            type: 'high_rating_amplification',
            should_generate: true,
            reasoning: "High rating (#{rating_value}/#{max_rating}) presents opportunity to understand success factors",
            confidence: 0.7,
            focus: 'success_factors'
          }
        else
          strategy = {
            type: 'neutral_rating_clarification',
            should_generate: true,
            reasoning: "Neutral rating suggests room for improvement understanding",
            confidence: 0.6,
            focus: 'improvement_opportunities'
          }
        end
        
      when 'multiple_choice', 'single_choice'
        # Check if "Other" was selected or if answer suggests elaboration
        if answer_value.to_s.downcase.include?('other')
          strategy = {
            type: 'other_option_elaboration',
            should_generate: true,
            reasoning: "User selected 'Other' option, needs elaboration",
            confidence: 0.95,
            focus: 'specification'
          }
        elsif source_question.question_config&.dig('allow_elaboration')
          strategy = {
            type: 'choice_elaboration',
            should_generate: true,
            reasoning: "Choice question configured for elaboration",
            confidence: 0.7,
            focus: 'reasoning'
          }
        else
          # Check if this choice typically leads to follow-ups
          strategy = analyze_choice_patterns(source_question, answer_value, previous_responses)
        end
        
      when 'text_short', 'text_long'
        text_analysis = analyze_text_answer(answer_value.to_s)
        
        if text_analysis[:suggests_issues]
          strategy = {
            type: 'issue_investigation',
            should_generate: true,
            reasoning: "Text response suggests issues or concerns that need follow-up",
            confidence: 0.8,
            focus: 'problem_solving'
          }
        elsif text_analysis[:suggests_enthusiasm]
          strategy = {
            type: 'enthusiasm_exploration',
            should_generate: true,
            reasoning: "Positive response suggests opportunity for deeper engagement",
            confidence: 0.7,
            focus: 'opportunity_exploration'
          }
        elsif text_analysis[:too_brief]
          strategy = {
            type: 'elaboration_request',
            should_generate: true,
            reasoning: "Brief response suggests more information could be gathered",
            confidence: 0.6,
            focus: 'detail_gathering'
          }
        else
          strategy = {
            type: 'contextual_followup',
            should_generate: true,
            reasoning: "Standard contextual follow-up based on text content",
            confidence: 0.5,
            focus: 'context_building'
          }
        end
        
      when 'yes_no', 'boolean'
        bool_value = ['yes', 'true', '1', 'y'].include?(answer_value.to_s.downcase)
        
        if bool_value
          strategy = {
            type: 'positive_response_exploration',
            should_generate: true,
            reasoning: "Positive response opens opportunity for deeper exploration",
            confidence: 0.8,
            focus: 'elaboration'
          }
        else
          strategy = {
            type: 'negative_response_investigation',
            should_generate: true,
            reasoning: "Negative response may indicate barriers or issues to explore",
            confidence: 0.8,
            focus: 'barrier_identification'
          }
        end
        
      else
        # For other question types, use general strategy
        strategy = {
          type: 'general_followup',
          should_generate: true,
          reasoning: "General follow-up for #{source_question.question_type} question type",
          confidence: 0.5,
          focus: 'general_information'
        }
      end
      
      # Check if we should skip generation based on form context
      if should_skip_generation?(source_question, answer_data, previous_responses)
        strategy[:should_generate] = false
        strategy[:skip_reason] = determine_skip_reason(source_question, answer_data, previous_responses)
      end
      
      strategy
    end
    
    # Calculate priority for generating this dynamic question
    def calculate_generation_priority(source_question, answer_data, strategy)
      base_priority = case strategy[:type]
                      when 'low_rating_investigation', 'issue_investigation', 'other_option_elaboration'
                        'high'
                      when 'high_rating_amplification', 'negative_response_investigation', 'positive_response_exploration'
                        'medium'
                      else
                        'low'
                      end
      
      # Adjust based on question position (earlier questions get higher priority)
      if source_question.position <= 3
        base_priority = upgrade_priority(base_priority)
      end
      
      # Adjust based on strategy confidence
      if strategy[:confidence] >= 0.8
        base_priority = upgrade_priority(base_priority)
      elsif strategy[:confidence] <= 0.4
        base_priority = downgrade_priority(base_priority)
      end
      
      base_priority
    end
    
    # Suggest the most appropriate question type for the follow-up
    def suggest_question_type(source_question, answer_data, strategy)
      case strategy[:focus]
      when 'problem_identification', 'barrier_identification', 'issue_investigation'
        'text_short' # Allow open-ended explanation of problems
      when 'success_factors', 'opportunity_exploration'
        'multiple_choice' # Provide structured options for success factors
      when 'specification', 'elaboration', 'detail_gathering'
        'text_long' # Allow detailed explanation
      when 'reasoning'
        'text_short' # Brief explanation of reasoning
      when 'improvement_opportunities'
        'rating' # Rate specific improvement areas
      else
        'text_short' # Default to short text for general follow-ups
      end
    end  
  
    # Analyze choice patterns to determine follow-up strategy
    def analyze_choice_patterns(source_question, answer_value, previous_responses)
      # This could be enhanced with ML in the future
      # For now, use rule-based analysis
      
      choice_config = source_question.question_config || {}
      options = choice_config['options'] || []
      
      # Find the selected option details
      selected_option = options.find { |opt| opt['value'] == answer_value || opt['label'] == answer_value }
      
      if selected_option&.dig('triggers_followup')
        {
          type: 'configured_choice_followup',
          should_generate: true,
          reasoning: "Choice option is configured to trigger follow-up questions",
          confidence: 0.8,
          focus: 'choice_elaboration'
        }
      else
        {
          type: 'standard_choice_followup',
          should_generate: false,
          reasoning: "Choice does not typically require follow-up",
          confidence: 0.3,
          skip_reason: 'choice_sufficient'
        }
      end
    end
    
    # Analyze text answers for sentiment and content indicators
    def analyze_text_answer(text)
      return { suggests_issues: false, suggests_enthusiasm: false, too_brief: true } if text.blank?
      
      text_lower = text.downcase
      word_count = text.split.length
      
      # Issue indicators
      issue_keywords = [
        'problem', 'issue', 'difficult', 'hard', 'confusing', 'unclear', 'frustrated',
        'annoying', 'slow', 'broken', 'error', 'fail', 'wrong', 'bad', 'terrible',
        'hate', 'dislike', 'disappointed', 'concern', 'worry', 'trouble'
      ]
      
      # Enthusiasm indicators
      enthusiasm_keywords = [
        'love', 'great', 'excellent', 'amazing', 'fantastic', 'wonderful', 'perfect',
        'awesome', 'brilliant', 'outstanding', 'impressed', 'excited', 'thrilled',
        'delighted', 'satisfied', 'happy', 'pleased', 'enjoy', 'like'
      ]
      
      suggests_issues = issue_keywords.any? { |keyword| text_lower.include?(keyword) }
      suggests_enthusiasm = enthusiasm_keywords.any? { |keyword| text_lower.include?(keyword) }
      too_brief = word_count < 3
      
      {
        suggests_issues: suggests_issues,
        suggests_enthusiasm: suggests_enthusiasm,
        too_brief: too_brief,
        word_count: word_count,
        sentiment_indicators: {
          negative_keywords: issue_keywords.select { |k| text_lower.include?(k) },
          positive_keywords: enthusiasm_keywords.select { |k| text_lower.include?(k) }
        }
      }
    end
    
    # Determine if generation should be skipped
    def should_skip_generation?(source_question, answer_data, previous_responses)
      # Skip if too many questions already answered
      return true if previous_responses.keys.length > 10
      
      # Skip if answer is too brief or empty
      answer_value = answer_data.is_a?(Hash) ? answer_data['value'] : answer_data
      return true if answer_value.blank? || answer_value.to_s.length < 2
      
      # Skip if this is a sensitive question type that shouldn't have follow-ups
      sensitive_types = ['email', 'phone', 'password', 'payment']
      return true if sensitive_types.include?(source_question.question_type)
      
      false
    end
    
    # Determine the reason for skipping generation
    def determine_skip_reason(source_question, answer_data, previous_responses)
      answer_value = answer_data.is_a?(Hash) ? answer_data['value'] : answer_data
      
      if previous_responses.keys.length > 10
        'form_too_long'
      elsif answer_value.blank?
        'empty_answer'
      elsif answer_value.to_s.length < 2
        'insufficient_content'
      elsif ['email', 'phone', 'password', 'payment'].include?(source_question.question_type)
        'sensitive_question_type'
      else
        'general_skip'
      end
    end
    
    # Helper methods for priority adjustment
    def upgrade_priority(current_priority)
      case current_priority
      when 'low' then 'medium'
      when 'medium' then 'high'
      else current_priority
      end
    end
    
    def downgrade_priority(current_priority)
      case current_priority
      when 'high' then 'medium'
      when 'medium' then 'low'
      else current_priority
      end
    end    

    # Format the LLM prompt for dynamic question generation
    def format_dynamic_question_prompt(context_data, strategy, suggested_question_type)
      form = context_data[:form]
      source_question = context_data[:source_question]
      answer_data = context_data[:answer_data]
      previous_responses = context_data[:previous_responses]
      form_response = context_data[:form_response]
      
      answer_value = answer_data.is_a?(Hash) ? answer_data['value'] : answer_data
      
      <<~PROMPT
        Generate a contextual follow-up question based on the user's response to enhance data collection and user engagement.

        **Form Context:**
        - Form Name: "#{form.name}"
        - Form Category: #{form.category || 'General'}
        - Form Purpose: #{form.form_settings&.dig('purpose') || 'Information collection'}
        - Total Questions in Form: #{form.form_questions.count}
        - AI Enhancement Level: #{form.ai_configuration&.dig('enhancement_level') || 'standard'}

        **Original Question Context:**
        - Question: "#{source_question.title}"
        - Type: #{source_question.question_type}
        - Position: #{source_question.position} of #{form.form_questions.count}
        - Required: #{source_question.required? ? 'Yes' : 'No'}
        - Description: #{source_question.description || 'None provided'}

        **User's Response:**
        "#{answer_value}"

        **Follow-up Strategy:**
        - Strategy Type: #{strategy[:type]}
        - Focus Area: #{strategy[:focus]}
        - Reasoning: #{strategy[:reasoning]}
        - Confidence Level: #{strategy[:confidence]}

        **Previous Form Responses (for context):**
        #{format_previous_responses_for_prompt(previous_responses)}

        **Response Progress:**
        - Questions Answered: #{previous_responses.keys.length}
        - Form Completion: #{form_response.progress_percentage}%
        - Session Duration: #{calculate_session_duration(form_response)}

        **Generation Guidelines:**
        1. **Natural Flow**: The follow-up should feel like a natural continuation of the conversation
        2. **Value Addition**: Only generate if it will gather genuinely useful information
        3. **User Experience**: Keep the question engaging and not burdensome
        4. **Contextual Relevance**: Build directly on their specific response
        5. **Strategic Focus**: Align with the #{strategy[:focus]} focus area

        **Question Type Guidance:**
        - Suggested Type: #{suggested_question_type}
        - Consider: #{get_question_type_guidance(suggested_question_type)}

        **Response Format (JSON):**
        {
          "question": {
            "title": "The follow-up question text (clear, conversational, specific)",
            "description": "Optional helpful context or instructions for the user",
            "question_type": "#{suggested_question_type}",
            "configuration": {
              #{get_configuration_template(suggested_question_type)}
            },
            "required": false,
            "placeholder": "Optional placeholder text for input fields"
          },
          "reasoning": "Detailed explanation of why this follow-up adds value and how it builds on their response",
          "confidence": 0.0-1.0,
          "priority": "high|medium|low",
          "expected_insights": [
            "List of specific insights this question could reveal"
          ],
          "conversation_flow": "Brief description of how this maintains natural conversation flow"
        }

        **Quality Standards:**
        - Question must be directly related to their response: "#{answer_value}"
        - Avoid generic or obvious questions
        - Focus on gathering actionable insights
        - Maintain conversational tone
        - Consider user's emotional state and engagement level
        - Ensure the question feels valuable, not intrusive

        **Specific Instructions for #{strategy[:type]}:**
        #{get_strategy_specific_instructions(strategy)}

        Generate a follow-up question that enhances the form's value while respecting the user's time and engagement.
      PROMPT
    end
    
    # Format previous responses for the prompt context
    def format_previous_responses_for_prompt(previous_responses)
      return "No previous responses" if previous_responses.empty?
      
      formatted = previous_responses.map do |question_title, answer|
        "- #{question_title}: #{answer}"
      end.join("\n")
      
      # Limit to last 5 responses to keep prompt manageable
      lines = formatted.split("\n")
      if lines.length > 5
        recent_lines = lines.last(5)
        "#{recent_lines.join("\n")}\n(... #{lines.length - 5} earlier responses)"
      else
        formatted
      end
    end
    
    # Calculate session duration for context
    def calculate_session_duration(form_response)
      return "Unknown" unless form_response.created_at
      
      duration_seconds = Time.current - form_response.created_at
      
      if duration_seconds < 60
        "#{duration_seconds.to_i} seconds"
      elsif duration_seconds < 3600
        "#{(duration_seconds / 60).to_i} minutes"
      else
        "#{(duration_seconds / 3600).round(1)} hours"
      end
    end
    
    # Get question type specific guidance
    def get_question_type_guidance(question_type)
      case question_type
      when 'text_short'
        'Brief, focused responses (1-2 sentences). Good for specific details or clarifications.'
      when 'text_long'
        'Detailed explanations or stories. Use when you need comprehensive information.'
      when 'multiple_choice'
        'Structured options when you can predict likely responses. Faster for users.'
      when 'single_choice'
        'One selection from predefined options. Good for categorization.'
      when 'rating'
        'Numerical scale for measuring satisfaction, likelihood, or intensity.'
      when 'yes_no'
        'Simple binary choice. Use for clear yes/no decisions.'
      when 'scale'
        'Numerical scale (0-10) for more granular measurement than rating.'
      else
        'Choose the type that best matches the expected response format.'
      end
    end
    
    # Get configuration template for question type
    def get_configuration_template(question_type)
      case question_type
      when 'text_short'
        '"max_length": 255'
      when 'text_long'
        '"max_length": 2000'
      when 'multiple_choice'
        '"options": [{"label": "Option 1", "value": "option1"}, {"label": "Option 2", "value": "option2"}], "allow_multiple": false'
      when 'single_choice'
        '"options": [{"label": "Option 1", "value": "option1"}, {"label": "Option 2", "value": "option2"}]'
      when 'rating'
        '"min_value": 1, "max_value": 5, "labels": {"min": "Poor", "max": "Excellent"}'
      when 'scale'
        '"min_value": 0, "max_value": 10, "labels": {"min": "Not at all", "max": "Extremely"}'
      when 'yes_no'
        '"true_label": "Yes", "false_label": "No"'
      else
        '// Configuration specific to question type'
      end
    end
    
    # Get strategy-specific instructions
    def get_strategy_specific_instructions(strategy)
      case strategy[:type]
      when 'low_rating_investigation'
        "Focus on understanding the specific issues behind the low rating. Ask about particular pain points, what could be improved, or what caused the dissatisfaction. Be empathetic and solution-oriented."
        
      when 'high_rating_amplification'
        "Explore what made the experience positive. Ask about specific features, moments, or aspects they valued most. This helps identify success factors and potential testimonial content."
        
      when 'other_option_elaboration'
        "The user selected 'Other' - ask them to specify what they meant. Keep it open-ended but focused on getting the specific information that wasn't covered by the provided options."
        
      when 'issue_investigation'
        "Their response suggests problems or concerns. Ask for specific details about the issues, their impact, or potential solutions. Be supportive and focused on problem-solving."
        
      when 'enthusiasm_exploration'
        "They seem positive or excited. Ask what specifically they're enthusiastic about, or how they envision using/benefiting from what you're discussing."
        
      when 'elaboration_request'
        "Their response was brief. Ask for more details, examples, or context. Make it feel like you're genuinely interested in their perspective, not just collecting data."
        
      when 'positive_response_exploration'
        "They answered positively. Dig deeper into their experience, preferences, or how this positive aspect could be enhanced or expanded."
        
      when 'negative_response_investigation'
        "They answered negatively. Understand the barriers, concerns, or reasons behind their response. Focus on what might change their perspective."
        
      else
        "Generate a natural follow-up that builds on their specific response and gathers valuable additional information."
      end
    end
  end
end