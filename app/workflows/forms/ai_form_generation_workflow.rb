# frozen_string_literal: true

module Forms
  class AiFormGenerationWorkflow < ApplicationWorkflow
    
    workflow do
      # Step 1: Validate and prepare content for AI processing
      task :validate_and_prepare_content do
        process do |context|
          user_id = context.get(:user_id)
          content_input = context.get(:content_input)
          input_type = context.get(:input_type)
          metadata = context.get(:metadata) || {}
          Rails.logger.info "Starting AI form generation for user_id: #{user_id}, input_type: #{input_type}"
          
          # Validate required inputs
          if user_id.blank? || content_input.blank? || input_type.blank?
            missing = []
            missing << 'user_id' if user_id.blank?
            missing << 'content_input' if content_input.blank?
            missing << 'input_type' if input_type.blank?
            Rails.logger.warn "[validate_and_prepare_content] Missing inputs: #{missing}"
            raise "Missing required inputs: #{missing.join(', ')}"
          end
          
          # Load and validate user
          user = User.find_by(id: user_id)
          unless user
            raise "User not found"
          end
          
          # Check AI credits
          unless user.can_use_ai_features?
            raise "AI features require a premium subscription"
          end
          
          if user.ai_credits_remaining <= 0
            raise "Monthly AI usage limit exceeded"
          end
          
          # Process content
          if input_type == 'prompt'
            content = content_input.to_s.strip
            word_count = content.split(/\s+/).length
          elsif input_type == 'document'
            # Process uploaded document
            content = Forms::AiFormGenerationWorkflow.new.send(:process_document, content_input)
            word_count = content.split(/\s+/).length
          else
            raise "Unsupported input type: #{input_type}"
          end
          
          # Validate content length
          if word_count < 10
            raise "Content must be at least 10 words long"
          elsif word_count > 5000
            raise "Content is too long (maximum 5000 words)"
          end
          
          Rails.logger.info "Content validation successful - #{word_count} words processed"
          
          {
            user: user,
            content: content,
            word_count: word_count,
            estimated_cost: 0.05
          }
        end
      end

      # Step 2: Generate form using AI
      llm :generate_form do
        model "gpt-4o-mini"
        temperature 0.3
        max_tokens 2000
        
        system_prompt "You are an expert form designer. Generate a complete form structure based on the user's requirements. Return valid JSON only."
        
        prompt <<~PROMPT
          Create a form based on this request: {{validate_and_prepare_content.content}}
          
          Generate a JSON response with this exact structure:
          {
            "form_name": "Form title",
            "description": "Brief description", 
            "questions": [
              {
                "title": "Question text",
                "type": "text_short",
                "required": true,
                "config": {}
              }
            ]
          }
          
          Available question types and their config formats:
          - text_short, text_long, email, phone, date: config = {}
          - multiple_choice, single_choice: config = {"options": ["Option 1", "Option 2"]}
          - rating: config = {"min_value": 1, "max_value": 5, "labels": ["Poor", "Excellent"]}
          
          IMPORTANT: 
          - Use proper JSON format with quoted strings
          - For rating questions, use "min_value" and "max_value" as numbers
          - Always include at least 2 options for choice questions
          - Create 5-10 relevant questions for this form
          - Return ONLY valid JSON, no markdown formatting
        PROMPT
      end

      # Step 3: Create form in database
      task :create_form do
        process do |context|
          validation_result = context.get(:validate_and_prepare_content)
          form_data = context.get(:generate_form)
          user = validation_result[:user]
          
          # The LLM task already returns the response string directly
          Rails.logger.info "LLM task result type: #{form_data.class}"
          Rails.logger.info "LLM response length: #{form_data.length} characters" if form_data.is_a?(String)
          
          # Parse the AI response
          begin
            # Force conversion to string to avoid any metaprogramming issues
            form_data_str = form_data.to_s
            Rails.logger.info "Converted to string: #{form_data_str.class} - length: #{form_data_str.length}"
            
            if form_data_str.is_a?(String) && form_data_str.length > 0
              # Extract JSON from the response (handle various formats)
              json_match = form_data_str.match(/```json\s*\n?(.*?)\n?```/m) || 
                          form_data_str.match(/\{.*\}/m)
              
              if json_match
                cleaned_data = (json_match[1] || json_match[0]).to_s
                Rails.logger.info "Extracted JSON match: #{cleaned_data.class} - #{cleaned_data[0..100]}..."
                
                # Clean up common AI formatting issues - bypass method call for now
                cleaned_data = cleaned_data.strip
                Rails.logger.info "After cleaning: #{cleaned_data.class} - #{cleaned_data[0..100]}..."
                
                Rails.logger.info "About to parse JSON with: #{cleaned_data.class}"
                form_structure = JSON.parse(cleaned_data)
              else
                Rails.logger.error "No JSON found in AI response: #{form_data_str}"
                raise "No valid JSON found in AI response"
              end
            else
              Rails.logger.error "Invalid form_data type or empty: #{form_data.class}"
              raise "Invalid AI response format"
            end
          rescue JSON::ParserError => e
            Rails.logger.error "Failed to parse AI response: #{e.message}"
            Rails.logger.error "Raw response: #{form_data}"
            raise "Invalid AI response format"
          end
          
          # Create the form
          begin
            ActiveRecord::Base.transaction do
              form = user.forms.create!(
                name: form_structure['form_name'] || 'AI Generated Form',
                description: form_structure['description'] || 'Generated by AI',
                category: 'general',
                ai_enabled: true,
                status: 'draft'
              )
              
              # Create questions
              questions = form_structure['questions'] || []
              questions.each_with_index do |question_data, index|
                question_type = question_data['type'] || 'text_short'
                config = question_data['config'] || {}
                
                # Validate and fix config based on question type - inline to avoid method interception
                case question_type
                when 'multiple_choice', 'single_choice'
                  # Ensure options exist
                  if config['options'].blank? || !config['options'].is_a?(Array)
                    config['options'] = ['Option 1', 'Option 2']
                  end
                when 'rating'
                  # Ensure min_value and max_value exist
                  config['min_value'] = config['min_value'] || 1
                  config['max_value'] = config['max_value'] || 5
                  
                  # Convert to integers if they're strings
                  config['min_value'] = config['min_value'].to_i
                  config['max_value'] = config['max_value'].to_i
                  
                  # Ensure max > min
                  if config['max_value'] <= config['min_value']
                    config['min_value'] = 1
                    config['max_value'] = 5
                  end
                when 'scale'
                  # Similar to rating
                  config['min_value'] = config['min_value'] || 1
                  config['max_value'] = config['max_value'] || 10
                  config['min_value'] = config['min_value'].to_i
                  config['max_value'] = config['max_value'].to_i
                  
                  if config['max_value'] <= config['min_value']
                    config['min_value'] = 1
                    config['max_value'] = 10
                  end
                end
                
                form.form_questions.create!(
                  title: question_data['title'],
                  question_type: question_type,
                  required: question_data['required'] || false,
                  position: index + 1,
                  question_config: config
                )
              end
              
              # Update user's AI credits
              user.increment!(:ai_credits_used, validation_result[:estimated_cost])
              
              Rails.logger.info "Successfully created form with ID: #{form.id} (#{questions.length} questions)"
              
              {
                form: form,
                questions_count: questions.length,
                generation_cost: validation_result[:estimated_cost]
              }
            end
          rescue ActiveRecord::RecordInvalid => e
            Rails.logger.error "Failed to create form: #{e.message}"
            raise "Failed to create form: #{e.message}"
          rescue StandardError => e
            Rails.logger.error "Unexpected error creating form: #{e.message}"
            Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
            raise "An unexpected error occurred: #{e.message}"
          end
        end
      end
    end

    private

    def clean_ai_json_response(json_string)
      # Fix common AI JSON formatting issues
      cleaned = json_string.dup
      
      # Fix scale format like "scale": 1-5 to "min_value": 1, "max_value": 5
      cleaned = cleaned.gsub(/"scale":\s*(\d+)-(\d+)/) do |match|
        min_val = $1
        max_val = $2
        "\"min_value\": #{min_val}, \"max_value\": #{max_val}"
      end
      
      # Fix unquoted values in config
      cleaned = cleaned.gsub(/:\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*([,}])/) do |match|
        value = $1
        ending = $2
        # Don't quote if it's already a number, boolean, or null
        if value.match?(/^(true|false|null|\d+)$/)
          match
        else
          ": \"#{value}\"#{ending}"
        end
      end
      
      # Remove trailing commas before closing brackets/braces
      cleaned = cleaned.gsub(/,(\s*[}\]])/, '\1')
      
      Rails.logger.debug "Cleaned JSON: #{cleaned}"
      cleaned
    end

    def validate_and_fix_question_config(question_type, config)
      case question_type
      when 'multiple_choice', 'single_choice'
        # Ensure options exist
        if config['options'].blank? || !config['options'].is_a?(Array)
          config['options'] = ['Option 1', 'Option 2']
        end
      when 'rating'
        # Ensure min_value and max_value exist
        config['min_value'] = config['min_value'] || 1
        config['max_value'] = config['max_value'] || 5
        
        # Convert to integers if they're strings
        config['min_value'] = config['min_value'].to_i
        config['max_value'] = config['max_value'].to_i
        
        # Ensure max > min
        if config['max_value'] <= config['min_value']
          config['min_value'] = 1
          config['max_value'] = 5
        end
      when 'scale'
        # Similar to rating
        config['min_value'] = config['min_value'] || 1
        config['max_value'] = config['max_value'] || 10
        config['min_value'] = config['min_value'].to_i
        config['max_value'] = config['max_value'].to_i
        
        if config['max_value'] <= config['min_value']
          config['min_value'] = 1
          config['max_value'] = 10
        end
      end
      
      config
    end

    def process_document(uploaded_file)
      Rails.logger.info "Processing document: #{uploaded_file.original_filename}"
      
      # Validate file type
      allowed_types = ['application/pdf', 'text/plain', 'text/markdown']
      unless allowed_types.include?(uploaded_file.content_type)
        raise "Unsupported file type: #{uploaded_file.content_type}"
      end
      
      # Validate file size (10MB limit)
      if uploaded_file.size > 10.megabytes
        raise "File too large: #{uploaded_file.size} bytes (max 10MB)"
      end
      
      case uploaded_file.content_type
      when 'application/pdf'
        extract_text_from_pdf(uploaded_file)
      when 'text/plain', 'text/markdown'
        uploaded_file.read.force_encoding('UTF-8')
      else
        raise "Unsupported file type: #{uploaded_file.content_type}"
      end
    end

    def extract_text_from_pdf(uploaded_file)
      begin
        # Try to use pdf-reader gem if available
        if defined?(PDF::Reader)
          reader = PDF::Reader.new(uploaded_file.tempfile)
          text = reader.pages.map(&:text).join("\n")
          
          # Clean up the text
          text = text.gsub(/\s+/, ' ').strip
          
          if text.blank?
            raise "Could not extract text from PDF - file may be image-based or corrupted"
          end
          
          Rails.logger.info "Successfully extracted #{text.length} characters from PDF"
          return text
        else
          # Fallback: try to read as plain text (won't work for most PDFs)
          Rails.logger.warn "PDF::Reader gem not available, attempting fallback text extraction"
          content = uploaded_file.read.force_encoding('UTF-8')
          
          # Basic cleanup for text that might have been extracted
          if content.length > 100 && content.include?('PDF')
            # This is likely a PDF header, not actual content
            raise "PDF text extraction requires the pdf-reader gem. Please install it or upload a text file instead."
          end
          
          return content
        end
      rescue => e
        Rails.logger.error "PDF processing failed: #{e.message}"
        raise "Failed to process PDF: #{e.message}. Please try uploading a text or markdown file instead."
      end
    end
  end
end