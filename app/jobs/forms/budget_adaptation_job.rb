# app/jobs/forms/budget_adaptation_job.rb

class Forms::BudgetAdaptationJob < ApplicationJob
  queue_as :default

  def perform(form_response_id, budget_answer)
    Rails.logger.info "Starting BudgetAdaptationJob for response ID: #{form_response_id}"
    Rails.logger.info "Budget answer: '#{budget_answer}'"
    
    begin
      form_response = FormResponse.find(form_response_id)
      
      # Extract budget amount from text answer
      budget_amount = extract_budget_amount(budget_answer)
      Rails.logger.info "Extracted amount: #{budget_amount}"
      
      # Check if it's a low budget OR indicates budget constraints
      is_low_budget = determine_low_budget(budget_answer, budget_amount)
      Rails.logger.info "Is low budget: #{is_low_budget}"
      
      unless is_low_budget
        Rails.logger.info "Budget doesn't require follow-up, skipping dynamic question"
        return
      end
      
      # Check for existing questions
      existing = form_response.dynamic_questions
                             .where("generation_context @> ?", { trigger: 'budget_adaptation' }.to_json)
                             .exists?
      
      if existing
        Rails.logger.info "Budget adaptation question already exists"
        return
      end
      
      # Create contextual question based on the answer type
      question_data = generate_contextual_question(budget_answer, budget_amount)
      
      # Create dynamic question
      dynamic_question = DynamicQuestion.create!(
        form_response: form_response,
        generated_from_question: form_response.question_responses.last&.form_question,
        question_type: 'text_long',
        title: question_data[:title],
        description: question_data[:description],
        generation_context: { 
          trigger: 'budget_adaptation', 
          budget_amount: budget_amount,
          original_answer: budget_answer,
          question_type: question_data[:type]
        }
      )
      
      Rails.logger.info "✓ Dynamic question created: #{dynamic_question.id}"
      
      # WAIT A BIT FOR WEBSOCKET TO CONNECT
      Rails.logger.info "Waiting to ensure WebSocket connection..."
      sleep(2) # Wait 2 seconds for WebSocket to establish
      
      # Broadcast using Turbo Streams
      Rails.logger.info "Sending broadcast..."
      Turbo::StreamsChannel.broadcast_append_to(
        form_response,
        target: "budget_adaptation_#{form_response.id}",
        partial: "responses/budget_adaptation_question",
        locals: {
          dynamic_question: dynamic_question,
          form_response: form_response
        }
      )
      
      Rails.logger.info "✓ Broadcast sent successfully"
      
      # ALSO TRY ALTERNATIVE BROADCAST METHOD
      Rails.logger.info "Sending alternative broadcast..."
      begin
        html_content = ApplicationController.render(
          partial: "responses/budget_adaptation_question",
          locals: {
            dynamic_question: dynamic_question,
            form_response: form_response
          }
        )
        
        # Direct ActionCable broadcast
        ActionCable.server.broadcast(
          "turbo_streams_for_#{form_response.to_sgid_param}",
          "<turbo-stream action='append' target='budget_adaptation_#{form_response.id}'><template>#{html_content}</template></turbo-stream>"
        )
        
        Rails.logger.info "✓ Broadcast alternativo enviado"
        
      rescue => alt_error
        Rails.logger.error "Alternative broadcast failed: #{alt_error.message}"
      end
      
    rescue => error
      Rails.logger.error "BudgetAdaptationJob failed: #{error.message}"
      Rails.logger.error error.backtrace.first(5).join("\n")
    end
  end

  private

  def extract_budget_amount(budget_text)
    return 0.0 if budget_text.blank?
    
    text = budget_text.to_s.downcase.strip
    
    # Handle written numbers first
    written_numbers = {
      'zero' => 0, 'cero' => 0,
      'one hundred' => 100, 'cien' => 100,
      'two hundred' => 200, 'doscientos' => 200,
      'three hundred' => 300, 'trescientos' => 300,
      'four hundred' => 400, 'cuatrocientos' => 400,
      'five hundred' => 500, 'quinientos' => 500,
      'one thousand' => 1000, 'mil' => 1000,
      'two thousand' => 2000, 'dos mil' => 2000,
      'three thousand' => 3000, 'tres mil' => 3000,
      'five thousand' => 5000, 'cinco mil' => 5000,
      'ten thousand' => 10000, 'diez mil' => 10000
    }
    
    written_numbers.each do |written, value|
      if text.include?(written)
        return value.to_f
      end
    end
    
    # Extract numeric values with various patterns
    patterns = [
      /(\d+(?:\.\d+)?)\s*k\b/i,  # 1k, 2.5k
      /(\d+(?:[,.]?\d+)*)\s*(?:usd|dollars?|pesos?|€|euros?)\b/i,  # 1000 usd, 500 dollars
      /[$€£¥₹]\s*(\d+(?:[,.]?\d+)*)/,  # $1000, €500
      /(\d+(?:[,.]?\d+)*)/  # Just numbers
    ]
    
    patterns.each do |pattern|
      match = text.match(pattern)
      if match
        number_str = match[1]
        if pattern == /(\d+(?:\.\d+)?)\s*k\b/i
          # Handle 'k' suffix (thousands)
          return number_str.to_f * 1000
        else
          # Clean and convert
          clean_number = number_str.gsub(',', '').to_f
          return clean_number if clean_number > 0
        end
      end
    end
    
    0.0
  end

  def determine_low_budget(budget_text, extracted_amount)
    return false if budget_text.blank?
    
    text = budget_text.to_s.downcase.strip
    
    # Explicit low budget indicators
    low_budget_phrases = [
      'limited', 'small', 'tight', 'low', 'minimal', 'constrained',
      'not much', 'very little',
      'bootstrap', 'startup budget', 'shoestring',
      'no budget'
    ]
    
    # Check for explicit low budget language
    if low_budget_phrases.any? { |phrase| text.include?(phrase) }
      return true
    end
    
    # If we extracted a number, use threshold
    if extracted_amount > 0
      return extracted_amount < 2000  # Increased threshold for AI projects
    end
    
    # Check for ranges that suggest low budget
    low_ranges = [
      /under \$?(\d+)/i,
      /less than \$?(\d+)/i,
      /below \$?(\d+)/i
    ]
    
    low_ranges.each do |range_pattern|
      match = text.match(range_pattern)
      if match
        threshold = match[1].to_f
        return threshold < 3000  # If they say "under 3000", consider it low
      end
    end
    
    false
  end

  def generate_contextual_question(budget_answer, budget_amount)
    text = budget_answer.to_s.downcase
    
    # Different question types based on the answer
    if budget_amount > 0
      # They gave a specific amount
      {
        type: 'specific_amount',
        title: "Let's optimize your $#{budget_amount.to_i} investment",
        description: "I understand you have a budget of $#{budget_amount.to_i} for AI projects. To help you get maximum value from this investment, could you share your main objectives and what you hope to achieve? This will help me suggest the best strategy within your budget."
      }
    elsif text.include?('limited') || text.include?('small') || text.include?('tight') || text.include?('limitado')
      # They indicated limited budget
      {
        type: 'limited_budget',
        title: "Maximize impact with limited budget",
        description: "I understand you're working with a limited budget for AI projects. This is very common and there are many effective ways to start. Could you tell me what specific business problem you hope to solve with AI? This will help me suggest cost-effective approaches that generate maximum impact."
      }
    elsif text.include?('startup') || text.include?('bootstrap')
      # Startup context
      {
        type: 'startup_budget',
        title: "AI strategy for startups",
        description: "Perfect, I understand you're in startup mode. The good news is that many modern AI solutions are very accessible for startups. What's the most critical business problem you believe AI could help solve? I'd like to suggest approaches that fit the reality of a startup."
      }
    else
      # General low budget case
      {
        type: 'general_constraint',
        title: "Let's understand your priorities",
        description: "Thank you for sharing your budget situation. To provide you with the best recommendations that fit your reality, could you tell me more about what you hope to achieve with AI and what your main priorities are? This way I can suggest options that really work for you."
      }
    end
  end
end