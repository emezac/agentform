# app/workflows/forms/budget_adaptation_workflow.rb
# frozen_string_literal: true

module Forms
  class BudgetAdaptationWorkflow < ApplicationWorkflow
    # Use the syntax that works with your existing workflow engine
    steps do
      
      step :analyze_budget, uses: :direct_handler, with: {
        handler: ->(context) {
          budget_answer = context.get(:budget_answer).to_s
          budget_amount = budget_answer.gsub(/[^0-9.]/, '').to_f
          Rails.logger.info "Budget analysis - Amount: #{budget_amount}, Is low budget: #{budget_amount > 0 && budget_amount < 1500}"
          { is_low_budget: budget_amount > 0 && budget_amount < 1500, budget_amount: budget_amount }
        }
      }
      
      step :generate_budget_question, uses: :llm,
        if: ->(context) { context.get(:analyze_budget)&.dig(:is_low_budget) },
        model: "gpt-4o-mini",
        temperature: 0.5,
        response_format: { type: "json_object" },
        system_prompt: "You are an AI that only returns valid JSON. Do not add any conversational text or markdown formatting. Your entire response must be a single, valid JSON object.",
        prompt: <<~PROMPT
          A prospect has a budget of {{analyze_budget.budget_amount}} USD.
          Generate an empathetic follow-up question in English to understand their priorities.
          Return a single JSON object with the keys "title", "question_type", and "description".
          The "question_type" must be "text_long".
        PROMPT
      
      step :save_and_stream_question, uses: :direct_handler, with: {
        if: ->(context) { context.get(:generate_budget_question).present? },
        handler: ->(context) {
          begin
            llm_output = context.get(:generate_budget_question)
            form_response_id = context.get(:form_response_id)
            
            Rails.logger.info "Processing LLM output: #{llm_output.inspect}"
            Rails.logger.info "Form response ID: #{form_response_id}"
            
            unless llm_output.is_a?(Hash) && llm_output['title'].present?
              Rails.logger.error "Invalid LLM output: #{llm_output}"
              return { success: false, reason: "Invalid LLM output", llm_output: llm_output }
            end

            form_response = FormResponse.find(form_response_id)
            Rails.logger.info "Found form response: #{form_response.id}, Session: #{form_response.session_id}"
            
            # 1. Save the question to database
            dynamic_question = DynamicQuestion.create!(
              form_response: form_response,
              generated_from_question: form_response.question_responses.last&.form_question,
              question_type: llm_output['question_type'] || 'text_long',
              title: llm_output['title'],
              description: llm_output['description'],
              generation_context: { trigger: 'budget_adaptation', llm_output: llm_output }
            )
            
            Rails.logger.info "Created dynamic question: #{dynamic_question.id}"
            
            # 2. Use Turbo::StreamsChannel.broadcast_append_to
            begin
              Turbo::StreamsChannel.broadcast_append_to(
                form_response, # Pass the FormResponse object
                target: "budget_adaptation_#{form_response.id}",
                partial: "responses/budget_adaptation_question",
                locals: {
                  dynamic_question: dynamic_question,
                  form_response: form_response
                }
              )
              
              Rails.logger.info "Turbo Stream broadcast sent for FormResponse: #{form_response.id}"
            rescue => broadcast_error
              Rails.logger.error "Broadcast failed: #{broadcast_error.message}"
              # Don't fail the whole workflow if broadcast fails
            end
            
            { success: true, streamed: true, dynamic_question_id: dynamic_question.id }
            
          rescue => error
            Rails.logger.error "Error in save_and_stream_question: #{error.message}"
            Rails.logger.error error.backtrace.first(5).join("\n")
            { success: false, error: error.message }
          end
        }
      }
    end

    # Add a run method that works with your job
    def run(context_data = {})
      Rails.logger.info "Running BudgetAdaptationWorkflow with context: #{context_data.keys}"
      
      begin
        # Set context
        context_data.each do |key, value|
          context.set(key, value)
        end
        
        # Execute the workflow using whatever method your engine provides
        if respond_to?(:execute)
          result = execute
        elsif respond_to?(:call)
          result = call
        else
          # Try to run the steps manually
          result = run_steps_manually(context_data)
        end
        
        Rails.logger.info "Workflow execution completed with result: #{result.inspect}"
        result
        
      rescue => error
        Rails.logger.error "Workflow execution failed: #{error.message}"
        { success: false, error: error.message }
      end
    end

    private

    def run_steps_manually(context_data)
      Rails.logger.info "Running steps manually"
      
      # Step 1: Analyze budget
      analyze_result = analyze_budget_step(context_data[:budget_answer])
      return analyze_result unless analyze_result[:is_low_budget]
      
      Rails.logger.info "Budget is low, generating question"
      
      # Step 2: Generate question
      question_result = generate_question_step(analyze_result[:budget_amount])
      return { success: false, reason: "Question generation failed" } unless question_result
      
      # Step 3: Save and stream
      save_result = save_and_stream_step(context_data[:form_response_id], question_result)
      
      save_result
    end

    def analyze_budget_step(budget_answer)
      budget_amount = budget_answer.to_s.gsub(/[^0-9.]/, '').to_f
      is_low_budget = budget_amount > 0 && budget_amount < 1500
      
      Rails.logger.info "Budget analysis - Amount: #{budget_amount}, Is low budget: #{is_low_budget}"
      
      { is_low_budget: is_low_budget, budget_amount: budget_amount }
    end

    def generate_question_step(budget_amount)
      # Simple fallback question generation
      {
        'title' => "Help us understand your priorities",
        'question_type' => 'text_long',
        'description' => "I understand you're working with a budget of $#{budget_amount}. Could you share what your main priorities are when allocating this budget? This will help us better understand how we can work together to achieve your goals."
      }
    end

    def save_and_stream_step(form_response_id, question_data)
      form_response = FormResponse.find(form_response_id)
      
      # Create dynamic question
      dynamic_question = DynamicQuestion.create!(
        form_response: form_response,
        generated_from_question: form_response.question_responses.last&.form_question,
        question_type: question_data['question_type'],
        title: question_data['title'],
        description: question_data['description'],
        generation_context: { trigger: 'budget_adaptation', manual: true }
      )
      
      Rails.logger.info "Created dynamic question: #{dynamic_question.id}"
      
      # Broadcast
      begin
        Turbo::StreamsChannel.broadcast_append_to(
          form_response,
          target: "budget_adaptation_#{form_response.id}",
          partial: "responses/budget_adaptation_question",
          locals: {
            dynamic_question: dynamic_question,
            form_response: form_response
          }
        )
        
        Rails.logger.info "Manual Turbo Stream broadcast sent"
      rescue => error
        Rails.logger.error "Manual broadcast failed: #{error.message}"
      end
      
      { success: true, dynamic_question_id: dynamic_question.id }
    end
  end
end