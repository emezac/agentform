# frozen_string_literal: true

module Forms
  # Service responsible for dynamically generating SuperAgent workflow classes for forms
  # This service creates custom workflow classes based on form configuration and questions
  class WorkflowGeneratorService < ApplicationService
    attr_reader :form, :workflow_class_name
    
    def initialize(form)
      @form = form
      @workflow_class_name = form.workflow_class_name
      super()
    end
    
    # Main execution method
    def call
      validate_service_inputs
      return self if failure?
      
      if workflow_exists?
        Rails.logger.info "Workflow class #{workflow_class_name} already exists"
        set_result(existing_workflow_class)
      else
        generate_new_workflow_class
      end
      
      self
    end
    
    # Generate a new workflow class for the form
    def generate_class
      call
      @result
    end
    
    # Regenerate an existing workflow class (removes old one first)
    def regenerate_class
      remove_existing_class if workflow_exists?
      generate_new_workflow_class
      @result
    end
    
    private
    
    # Validate service inputs
    def validate_service_inputs
      unless @form.is_a?(Form)
        add_error(:form, "must be a Form instance")
        return
      end
      
      unless @workflow_class_name.present?
        add_error(:workflow_class_name, "must be present")
        return
      end
      
      unless @form.form_questions.any?
        add_error(:form, "must have at least one question to generate workflow")
        return
      end
    end
    
    # Check if workflow class already exists
    def workflow_exists?
      return false unless @workflow_class_name.present?
      
      begin
        @workflow_class_name.constantize
        true
      rescue NameError
        false
      end
    end
    
    # Get existing workflow class
    def existing_workflow_class
      return nil unless workflow_exists?
      @workflow_class_name.constantize
    end
    
    # Generate a new workflow class
    def generate_new_workflow_class
      Rails.logger.info "Generating new workflow class: #{@workflow_class_name}"
      
      # Build workflow definition using the builder
      definition_builder = WorkflowDefinitionBuilder.new(@form)
      workflow_definition = definition_builder.build
      
      if workflow_definition.nil?
        add_error(:generation, "Failed to build workflow definition")
        return
      end
      
      # Create the actual workflow class
      workflow_class = create_workflow_class(workflow_definition)
      
      if workflow_class
        Rails.logger.info "Successfully generated workflow class: #{@workflow_class_name}"
        set_result(workflow_class)
      else
        add_error(:generation, "Failed to create workflow class")
      end
    end
    
    # Build workflow definition from form configuration
    def build_workflow_definition
      WorkflowDefinitionBuilder.new(@form).build
    end
    
    # Create the actual workflow class from definition
    def create_workflow_class(definition)
      begin
        # Generate the class code
        class_code = generate_class_code(definition)
        
        # Evaluate the class code to create the class
        eval(class_code)
        
        # Return the created class
        @workflow_class_name.constantize
      rescue StandardError => e
        Rails.logger.error "Failed to create workflow class: #{e.message}"
        Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
        add_error(:class_creation, "Failed to create class: #{e.message}")
        nil
      end
    end
    
    # Remove existing workflow class
    def remove_existing_class
      return unless workflow_exists?
      
      begin
        # Remove the constant to allow redefinition
        namespace, class_name = @workflow_class_name.split('::')
        if namespace && class_name
          namespace.constantize.send(:remove_const, class_name)
        else
          Object.send(:remove_const, @workflow_class_name)
        end
        
        Rails.logger.info "Removed existing workflow class: #{@workflow_class_name}"
      rescue StandardError => e
        Rails.logger.warn "Failed to remove existing class: #{e.message}"
      end
    end
    
    # Generate Ruby class code from workflow definition
    def generate_class_code(definition)
      <<~RUBY
        class #{@workflow_class_name} < ApplicationWorkflow
          workflow do
            #{generate_workflow_steps(definition)}
          end
          
          private
          
          #{generate_helper_methods(definition)}
        end
      RUBY
    end
    
    # Generate workflow steps code
    def generate_workflow_steps(definition)
      steps_code = []
      
      # Add global configuration
      if definition[:config]
        steps_code << generate_global_config(definition[:config])
      end
      
      # Add workflow steps
      definition[:steps]&.each do |step|
        steps_code << generate_step_code(step)
      end
      
      steps_code.join("\n\n")
    end
    
    # Generate global configuration code
    def generate_global_config(config)
      config_lines = []
      
      config_lines << "timeout #{config[:timeout]}" if config[:timeout]
      config_lines << "retry_policy #{config[:retry_policy]}" if config[:retry_policy]
      
      config_lines.join("\n")
    end
    
    # Generate code for a single workflow step
    def generate_step_code(step)
      case step[:type]
      when 'validate'
        generate_validation_step(step)
      when 'task'
        generate_task_step(step)
      when 'llm'
        generate_llm_step(step)
      when 'stream'
        generate_stream_step(step)
      else
        "# Unknown step type: #{step[:type]}"
      end
    end
    
    # Generate validation step code
    def generate_validation_step(step)
      <<~RUBY.strip
        validate :#{step[:name]} do
          #{generate_input_declaration(step[:inputs])}
          description "#{step[:description]}"
          
          process do |#{step[:inputs]&.join(', ')}|
            #{step[:process_code] || '# Validation logic here'}
          end
        end
      RUBY
    end
    
    # Generate task step code
    def generate_task_step(step)
      code = <<~RUBY.strip
        task :#{step[:name]} do
          #{generate_input_declaration(step[:inputs])}
      RUBY
      
      if step[:run_when]
        code += "\n          #{generate_conditional_logic(step[:run_when])}"
      end
      
      code += <<~RUBY
        
          process do |#{step[:inputs]&.join(', ')}|
            #{step[:process_code] || '# Task logic here'}
          end
        end
      RUBY
      
      code
    end
    
    # Generate LLM step code
    def generate_llm_step(step)
      code = <<~RUBY.strip
        llm :#{step[:name]} do
          #{generate_input_declaration(step[:inputs])}
      RUBY
      
      if step[:run_if]
        code += "\n          #{generate_conditional_logic(step[:run_if])}"
      end
      
      code += <<~RUBY
        
          model "#{step[:model] || 'gpt-4o-mini'}"
          temperature #{step[:temperature] || 0.3}
          max_tokens #{step[:max_tokens] || 500}
          response_format :#{step[:response_format] || 'json'}
          
          system_prompt "#{step[:system_prompt] || 'You are an AI assistant'}"
          prompt <<~PROMPT
            #{step[:prompt] || 'Process the input data'}
          PROMPT
        end
      RUBY
      
      code
    end
    
    # Generate stream step code
    def generate_stream_step(step)
      <<~RUBY.strip
        stream :#{step[:name]} do
          #{generate_input_declaration(step[:inputs])}
          
          target { |ctx| "#{step[:target] || 'default_target'}" }
          turbo_action :#{step[:turbo_action] || 'append'}
          partial "#{step[:partial] || 'default_partial'}"
          
          locals do |ctx|
            #{step[:locals_code] || '{}'}
          end
        end
      RUBY
    end
    
    # Generate input declaration code
    def generate_input_declaration(inputs)
      return "" unless inputs&.any?
      
      if inputs.is_a?(Array)
        "input #{inputs.map { |i| ":#{i}" }.join(', ')}"
      else
        "input :#{inputs}"
      end
    end
    
    # Generate conditional logic code
    def generate_conditional_logic(condition)
      case condition[:type]
      when 'run_when'
        "run_when :#{condition[:step]}, ->(result) { #{condition[:condition]} }"
      when 'run_if'
        "run_if { |ctx| #{condition[:condition]} }"
      else
        "# Unknown condition type: #{condition[:type]}"
      end
    end
    
    # Generate helper methods for the workflow class
    def generate_helper_methods(definition)
      helper_methods = []
      
      # Add form-specific helper methods
      helper_methods << <<~RUBY.strip
        def form
          @form ||= Form.find(context.get(:form_id))
        end
        
        def form_response
          @form_response ||= FormResponse.find(context.get(:form_response_id))
        end
        
        def current_question
          @current_question ||= FormQuestion.find(context.get(:question_id))
        end
      RUBY
      
      # Add any custom helper methods from definition
      if definition[:helper_methods]
        helper_methods << definition[:helper_methods]
      end
      
      helper_methods.join("\n\n")
    end
    
    # Nested class responsible for building workflow definitions from form configuration
    class WorkflowDefinitionBuilder
      attr_reader :form
      
      def initialize(form)
        @form = form
      end
      
      # Build complete workflow definition
      def build
        return nil unless @form&.form_questions&.any?
        
        {
          config: build_global_config,
          steps: build_steps,
          helper_methods: build_helper_methods
        }
      end
      
      private
      
      # Build global workflow configuration
      def build_global_config
        {
          timeout: determine_workflow_timeout,
          retry_policy: build_retry_policy
        }
      end
      
      # Determine appropriate timeout based on form complexity
      def determine_workflow_timeout
        base_timeout = 60 # 1 minute base
        question_count = @form.form_questions.count
        ai_questions = @form.form_questions.count { |q| q.ai_enhanced? }
        
        # Add time for each question (5 seconds base + 30 seconds per AI question)
        timeout = base_timeout + (question_count * 5) + (ai_questions * 30)
        
        # Cap at 10 minutes
        [timeout, 600].min
      end
      
      # Build retry policy configuration
      def build_retry_policy
        {
          max_retries: 2,
          delay: 1,
          exponential_backoff: true
        }
      end
      
      # Build all workflow steps
      def build_steps
        steps = []
        
        # Always start with form validation
        steps << build_form_validation_step
        
        # Add steps for each question
        @form.form_questions.ordered.each do |question|
          steps.concat(build_question_steps(question))
        end
        
        # Add completion step
        steps << build_completion_step
        
        steps
      end
      
      # Build form validation step
      def build_form_validation_step
        {
          type: 'validate',
          name: 'validate_form_data',
          inputs: ['form_response_id', 'question_id', 'answer_data'],
          description: 'Validate incoming form response data',
          process_code: <<~RUBY.strip
            form_response = FormResponse.find(form_response_id)
            question = FormQuestion.find(question_id)
            
            # Validate form response belongs to correct form
            unless form_response.form_id == question.form_id
              return { valid: false, error: 'Form response and question mismatch' }
            end
            
            # Validate question exists and is active
            unless question.active?
              return { valid: false, error: 'Question is not active' }
            end
            
            # Validate answer data format
            validation_result = question.validate_answer(answer_data)
            unless validation_result[:valid]
              return { valid: false, error: validation_result[:error] }
            end
            
            {
              valid: true,
              form_response: form_response,
              question: question,
              processed_answer: validation_result[:processed_answer]
            }
          RUBY
        }
      end
      
      # Build steps for a specific question
      def build_question_steps(question)
        steps = []
        
        # Save question response step
        steps << build_save_response_step(question)
        
        # Add AI analysis step if question is AI-enhanced
        if question.ai_enhanced?
          steps << build_ai_analysis_step(question)
          steps << build_update_with_ai_step(question)
        end
        
        # Add dynamic question generation if enabled
        if question.generates_followups?
          steps << build_dynamic_question_step(question)
        end
        
        # Add UI update step
        steps << build_ui_update_step(question)
        
        steps
      end
      
      # Build save response step
      def build_save_response_step(question)
        {
          type: 'task',
          name: "save_response_q#{question.position}",
          inputs: ['validate_form_data'],
          run_when: {
            type: 'run_when',
            step: 'validate_form_data',
            condition: 'result[:valid]'
          },
          process_code: <<~RUBY.strip
            validation_result = validate_form_data
            form_response = validation_result[:form_response]
            question = validation_result[:question]
            processed_answer = validation_result[:processed_answer]
            
            # Create or update question response
            question_response = form_response.question_responses.find_or_initialize_by(
              form_question: question
            )
            
            question_response.assign_attributes(
              answer_data: processed_answer,
              response_time_ms: context.get(:response_time_ms),
              metadata: context.get(:response_metadata, {})
            )
            
            if question_response.save
              # Update form response progress
              form_response.update_progress!
              
              {
                success: true,
                question_response: question_response,
                form_response: form_response
              }
            else
              {
                success: false,
                errors: question_response.errors.full_messages
              }
            end
          RUBY
        }
      end
      
      # Build AI analysis step for AI-enhanced questions
      def build_ai_analysis_step(question)
        {
          type: 'llm',
          name: "analyze_response_q#{question.position}",
          inputs: ["save_response_q#{question.position}"],
          run_if: {
            type: 'run_if',
            condition: build_ai_condition(question)
          },
          model: determine_ai_model(question),
          temperature: 0.3,
          max_tokens: 500,
          response_format: 'json',
          system_prompt: build_ai_system_prompt(question),
          prompt: build_analysis_prompt(question)
        }
      end
      
      # Build AI condition check
      def build_ai_condition(question)
        conditions = []
        
        # Check if AI features are enabled
        conditions << "@form.ai_enhanced?"
        
        # Check if user has AI credits
        conditions << "@form.user.can_use_ai_features?"
        
        # Check if question requires AI analysis
        conditions << "#{question.has_response_analysis?}"
        
        conditions.join(' && ')
      end
      
      # Determine appropriate AI model for question
      def determine_ai_model(question)
        # Use form's configured model or default
        @form.ai_configuration.dig('model') || 'gpt-4o-mini'
      end
      
      # Build AI system prompt
      def build_ai_system_prompt(question)
        case question.question_type
        when 'text_long', 'text_short'
          "You are an expert at analyzing text responses for sentiment, quality, and insights."
        when 'email'
          "You are an expert at analyzing email responses and detecting patterns."
        when 'rating', 'scale'
          "You are an expert at analyzing rating responses and identifying trends."
        else
          "You are an AI assistant analyzing form responses for insights and quality."
        end
      end
      
      # Build analysis prompt for question
      def build_analysis_prompt(question)
        <<~PROMPT
          Analyze the following form response:
          
          Question: "#{question.title}"
          Question Type: #{question.question_type}
          Response: {{answer_data}}
          
          Please provide analysis in the following JSON format:
          {
            "sentiment": "positive|neutral|negative",
            "confidence_score": 0.0-1.0,
            "quality_indicators": {
              "completeness": 0.0-1.0,
              "relevance": 0.0-1.0,
              "clarity": 0.0-1.0
            },
            "insights": ["insight1", "insight2"],
            "flags": ["flag1", "flag2"],
            "suggested_followup": "optional follow-up question"
          }
          
          Focus on:
          - Response quality and completeness
          - Emotional sentiment and tone
          - Potential red flags or concerns
          - Opportunities for follow-up questions
          - Business insights and patterns
        PROMPT
      end
      
      # Build step to update response with AI analysis
      def build_update_with_ai_step(question)
        {
          type: 'task',
          name: "update_ai_analysis_q#{question.position}",
          inputs: ["save_response_q#{question.position}", "analyze_response_q#{question.position}"],
          run_when: {
            type: 'run_when',
            step: "analyze_response_q#{question.position}",
            condition: 'result.present?'
          },
          process_code: <<~RUBY.strip
            save_result = context.get("save_response_q#{question.position}")
            ai_analysis = context.get("analyze_response_q#{question.position}")
            
            question_response = save_result[:question_response]
            
            # Update question response with AI analysis
            question_response.update!(
              ai_analysis: ai_analysis,
              ai_sentiment: ai_analysis['sentiment'],
              ai_confidence_score: ai_analysis['confidence_score'],
              quality_score: calculate_quality_score(ai_analysis['quality_indicators'])
            )
            
            # Track AI usage
            @form.user.consume_ai_credit(0.01) # Small cost for analysis
            
            {
              success: true,
              question_response: question_response,
              ai_analysis: ai_analysis
            }
          RUBY
        }
      end
      
      # Build dynamic question generation step
      def build_dynamic_question_step(question)
        {
          type: 'llm',
          name: "generate_followup_q#{question.position}",
          inputs: ["update_ai_analysis_q#{question.position}"],
          run_if: {
            type: 'run_if',
            condition: build_followup_condition(question)
          },
          model: determine_ai_model(question),
          temperature: 0.7,
          max_tokens: 300,
          response_format: 'json',
          system_prompt: "You are an expert at generating contextual follow-up questions.",
          prompt: build_followup_prompt(question)
        }
      end
      
      # Build condition for follow-up generation
      def build_followup_condition(question)
        conditions = []
        
        # Check if AI analysis suggests follow-up
        conditions << "ai_analysis = context.get('analyze_response_q#{question.position}')"
        conditions << "ai_analysis&.dig('suggested_followup').present?"
        
        # Check if form allows dynamic questions
        conditions << "@form.form_settings.dig('allow_dynamic_questions') != false"
        
        conditions.join(' && ')
      end
      
      # Build follow-up generation prompt
      def build_followup_prompt(question)
        <<~PROMPT
          Based on the user's response to: "#{question.title}"
          
          Response: {{answer_data}}
          AI Analysis: {{ai_analysis}}
          
          Generate a contextual follow-up question that:
          1. Builds naturally on their response
          2. Gathers additional valuable information
          3. Feels conversational, not interrogative
          4. Is relevant to the form's purpose
          
          Return JSON format:
          {
            "question": "The follow-up question text",
            "question_type": "text_short|text_long|multiple_choice|rating",
            "reasoning": "Why this follow-up is valuable",
            "configuration": {}
          }
        PROMPT
      end
      
      # Build UI update step
      def build_ui_update_step(question)
        {
          type: 'stream',
          name: "update_ui_q#{question.position}",
          inputs: ["save_response_q#{question.position}"],
          target: "form_#{@form.share_token}",
          turbo_action: 'replace',
          partial: 'responses/question_response',
          locals_code: <<~RUBY.strip
            save_result = context.get("save_response_q#{question.position}")
            {
              question_response: save_result[:question_response],
              form_response: save_result[:form_response]
            }
          RUBY
        }
      end
      
      # Build completion step
      def build_completion_step
        {
          type: 'task',
          name: 'complete_form_response',
          inputs: build_completion_inputs,
          process_code: <<~RUBY.strip
            form_response = context.get(:validate_form_data)[:form_response]
            
            # Check if all required questions are answered
            required_questions = @form.form_questions.where(required: true)
            answered_questions = form_response.question_responses.joins(:form_question)
                                            .where(form_questions: { required: true })
            
            if required_questions.count == answered_questions.count
              # Mark form as completed
              form_response.update!(
                status: 'completed',
                completed_at: Time.current,
                completion_data: {
                  total_time: Time.current - form_response.started_at,
                  questions_answered: form_response.question_responses.count,
                  ai_enhanced_responses: form_response.question_responses.where.not(ai_analysis: nil).count
                }
              )
              
              # Trigger integrations
              Forms::IntegrationTriggerJob.perform_async(form_response.id)
              
              {
                success: true,
                completed: true,
                form_response: form_response
              }
            else
              {
                success: true,
                completed: false,
                missing_required: required_questions.count - answered_questions.count
              }
            end
          RUBY
        }
      end
      
      # Build inputs for completion step
      def build_completion_inputs
        inputs = ['validate_form_data']
        
        # Add all save response steps as inputs
        @form.form_questions.each do |question|
          inputs << "save_response_q#{question.position}"
        end
        
        inputs
      end
      
      # Build helper methods for the workflow
      def build_helper_methods
        <<~RUBY.strip
          def calculate_quality_score(quality_indicators)
            return 0.0 unless quality_indicators.is_a?(Hash)
            
            scores = quality_indicators.values.map(&:to_f)
            return 0.0 if scores.empty?
            
            scores.sum / scores.length
          end
          
          def should_generate_followup?(ai_analysis, question)
            return false unless ai_analysis.is_a?(Hash)
            
            # Generate follow-up if AI suggests it and confidence is high
            ai_analysis['suggested_followup'].present? && 
            ai_analysis['confidence_score'].to_f > 0.7
          end
          
          def track_workflow_metrics(step_name, duration, success)
            Rails.logger.info "Workflow step #{step_name}: #{success ? 'SUCCESS' : 'FAILURE'} in #{duration}ms"
            
            # Track metrics if monitoring is available
            if defined?(StatsD)
              StatsD.timing("workflow.step.duration", duration, tags: ["step:#{step_name}"])
              StatsD.increment("workflow.step.#{success ? 'success' : 'failure'}", tags: ["step:#{step_name}"])
            end
          end
        RUBY
      end
    end
  end
end