# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Forms::AiFormGenerationWorkflow, type: :workflow do
  let(:user) { create(:user, ai_credits_used: 0.0, monthly_ai_limit: 10.0) }
  let(:prompt_content) { "I need a customer feedback form for my restaurant to collect reviews and suggestions from diners." }
  let(:metadata) { { source: 'web_interface' } }

  describe 'workflow structure' do
    it 'inherits from ApplicationWorkflow' do
      expect(described_class.superclass).to eq(ApplicationWorkflow)
    end

    it 'defines the expected workflow tasks' do
      workflow_instance = described_class.new
      
      # Check that the workflow class is properly defined
      expect(workflow_instance).to be_a(ApplicationWorkflow)
      expect(workflow_instance.class.name).to eq('Forms::AiFormGenerationWorkflow')
    end
  end

  describe '#validate_and_prepare_content task' do
    let(:workflow) { described_class.new }
    let(:valid_metadata) { { source: 'web_interface', timestamp: Time.current.iso8601 } }

    context 'with valid prompt input' do
      it 'processes content and returns structured result' do
        result = workflow.send(:process_prompt_input, prompt_content, valid_metadata)
        
        expect(result[:success]).to be true
        expect(result[:content]).to eq(prompt_content.strip)
        expect(result[:word_count]).to be > 10
        expect(result[:source_info][:type]).to eq('prompt')
      end

      it 'validates user AI credits successfully' do
        credit_result = workflow.send(:validate_ai_credits, user)
        
        expect(credit_result[:valid]).to be true
        expect(credit_result[:remaining]).to eq(10.0)
        expect(credit_result[:credits_used]).to eq(0.0)
        expect(credit_result[:monthly_limit]).to eq(10.0)
      end

      it 'validates content length within acceptable range' do
        word_count = prompt_content.split.length
        length_result = workflow.send(:validate_content_length, word_count)
        
        expect(length_result[:valid]).to be true
        expect(length_result[:message]).to include("appropriate")
      end

      it 'calculates estimated generation cost correctly' do
        word_count = 100
        cost = workflow.send(:calculate_estimated_generation_cost, word_count)
        
        expect(cost).to be > 0
        expect(cost).to be_a(Float)
        expect(cost).to be < 1.0 # Should be reasonable
      end
    end

    context 'with insufficient AI credits' do
      let(:user) { create(:user, ai_credits_used: 10.0, monthly_ai_limit: 10.0) }

      it 'fails validation due to credit limits' do
        credit_result = workflow.send(:validate_ai_credits, user)
        
        expect(credit_result[:valid]).to be false
        expect(credit_result[:message]).to include("Monthly AI usage limit exceeded")
        expect(credit_result[:remaining]).to eq(0.0)
      end
    end

    context 'with content validation edge cases' do
      it 'rejects content that is too short' do
        short_content = "Too short"
        word_count = short_content.split.length
        result = workflow.send(:validate_content_length, word_count)
        
        expect(result[:valid]).to be false
        expect(result[:message]).to include("Content too short")
        expect(result[:message]).to include("minimum 10 words")
      end

      it 'rejects content that is too long' do
        long_word_count = 5001
        result = workflow.send(:validate_content_length, long_word_count)
        
        expect(result[:valid]).to be false
        expect(result[:message]).to include("Content too long")
        expect(result[:message]).to include("Maximum 5000 words")
      end

      it 'handles empty prompt input' do
        result = workflow.send(:process_prompt_input, "", valid_metadata)
        
        expect(result[:success]).to be false
        expect(result[:message]).to include("cannot be empty")
        expect(result[:error_type]).to eq('empty_prompt')
      end

      it 'handles nil prompt input' do
        result = workflow.send(:process_prompt_input, nil, valid_metadata)
        
        expect(result[:success]).to be false
        expect(result[:message]).to include("cannot be empty")
      end
    end

    context 'with document input processing' do
      let(:mock_document) { double('document') }
      let(:mock_processor) { double('Ai::DocumentProcessor') }
      let(:successful_processing_result) do
        {
          success: true,
          content: "This is extracted document content with sufficient words for processing requirements.",
          metadata: {
            file_name: 'test.pdf',
            word_count: 12,
            page_count: 1
          },
          source_type: 'pdf_document'
        }
      end

      before do
        allow(Ai::DocumentProcessor).to receive(:new).with(file: mock_document).and_return(mock_processor)
      end

      it 'processes document successfully' do
        allow(mock_processor).to receive(:process).and_return(successful_processing_result)
        
        result = workflow.send(:process_document_input, mock_document, valid_metadata)
        
        expect(result[:success]).to be true
        expect(result[:content]).to include("extracted document content")
        expect(result[:word_count]).to eq(11) # Actual word count from the mock
        expect(result[:source_info][:type]).to eq('document')
      end

      it 'handles document processing failures' do
        failed_result = {
          success: false,
          errors: ['File format not supported', 'File too large']
        }
        allow(mock_processor).to receive(:process).and_return(failed_result)
        
        result = workflow.send(:process_document_input, mock_document, valid_metadata)
        
        expect(result[:success]).to be false
        expect(result[:message]).to include("Document processing failed")
        expect(result[:error_type]).to eq('document_processing_error')
        expect(result[:errors]).to eq(['File format not supported', 'File too large'])
      end

      it 'handles document processing exceptions' do
        allow(mock_processor).to receive(:process).and_raise(StandardError, "Unexpected processing error")
        expect(Rails.logger).to receive(:error).with("Document processing failed: Unexpected processing error")
        
        result = workflow.send(:process_document_input, mock_document, valid_metadata)
        
        expect(result[:success]).to be false
        expect(result[:message]).to include("Failed to process document")
        expect(result[:error_type]).to eq('document_processing_exception')
      end
    end

    context 'with invalid input types' do
      it 'rejects invalid input type' do
        result = workflow.send(:process_content_input, "content", "invalid_type", valid_metadata)
        
        expect(result[:success]).to be false
        expect(result[:message]).to include("Invalid input type: invalid_type")
        expect(result[:error_type]).to eq('invalid_input_type')
      end
    end
  end

  describe '#analyze_content_intent task' do
    let(:workflow) { described_class.new }
    let(:content_result) do
      {
        content: prompt_content,
        source_type: 'prompt',
        word_count: 20,
        metadata: { processed_at: Time.current.iso8601 }
      }
    end

    context 'with successful LLM analysis' do
      let(:mock_llm_response) do
        {
          'form_purpose' => 'Collect customer feedback for restaurant improvement',
          'target_audience' => 'Restaurant customers who have dined recently',
          'data_collection_goal' => 'Improve service quality and menu offerings',
          'recommended_approach' => 'feedback',
          'estimated_completion_time' => 5,
          'complexity_level' => 'moderate',
          'suggested_question_count' => 8,
          'key_topics' => ['food quality', 'service', 'ambiance'],
          'requires_branching_logic' => false,
          'form_category' => 'customer_feedback',
          'priority_data_points' => ['satisfaction', 'recommendations', 'return_likelihood'],
          'user_experience_considerations' => {
            'mobile_optimization' => true,
            'progress_indication' => true,
            'one_question_per_page' => false,
            'estimated_abandonment_risk' => 'low'
          }
        }.to_json
      end

      before do
        # Mock the LLM interface properly
        llm_interface = double('SuperAgent::LlmInterface')
        allow(SuperAgent::LlmInterface).to receive(:new).and_return(llm_interface)
        allow(llm_interface).to receive(:call).and_return(mock_llm_response)
      end

      it 'successfully analyzes content and returns structured result' do
        # This would be tested in integration - here we test the validation logic
        parsed_response = JSON.parse(mock_llm_response)
        validation_result = workflow.send(:validate_analysis_result, parsed_response)
        
        expect(validation_result[:valid]).to be true
        expect(validation_result[:errors]).to be_empty
      end

      it 'calculates confidence score correctly' do
        parsed_response = JSON.parse(mock_llm_response)
        confidence = workflow.send(:calculate_analysis_confidence, parsed_response)
        
        expect(confidence).to be >= 80.0
        expect(confidence).to be <= 100.0
      end
    end

    context 'with LLM response validation' do
      it 'validates complete analysis result' do
        valid_result = {
          'form_purpose' => 'Collect customer feedback for restaurant improvement',
          'target_audience' => 'Restaurant customers who have dined recently',
          'recommended_approach' => 'feedback',
          'complexity_level' => 'moderate',
          'estimated_completion_time' => 5,
          'suggested_question_count' => 8,
          'key_topics' => ['food quality', 'service', 'ambiance'],
          'requires_branching_logic' => false
        }
        
        result = workflow.send(:validate_analysis_result, valid_result)
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
      end

      it 'rejects analysis with missing required fields' do
        invalid_result = {
          'form_purpose' => 'Test form'
          # Missing other required fields
        }
        
        result = workflow.send(:validate_analysis_result, invalid_result)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include('target_audience is required')
        expect(result[:errors]).to include('recommended_approach is required')
        expect(result[:errors]).to include('complexity_level is required')
      end

      it 'rejects analysis with invalid enum values' do
        invalid_result = {
          'form_purpose' => 'Test form purpose that is long enough',
          'target_audience' => 'Test audience that is long enough',
          'recommended_approach' => 'invalid_approach',
          'complexity_level' => 'invalid_complexity'
        }
        
        result = workflow.send(:validate_analysis_result, invalid_result)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include('recommended_approach must be one of: survey, lead_capture, feedback, registration, assessment, other')
        expect(result[:errors]).to include('complexity_level must be one of: simple, moderate, complex')
      end

      it 'validates numeric fields correctly' do
        invalid_result = {
          'form_purpose' => 'Valid purpose with enough content',
          'target_audience' => 'Valid audience with enough content',
          'recommended_approach' => 'feedback',
          'complexity_level' => 'moderate',
          'estimated_completion_time' => -5,
          'suggested_question_count' => 0
        }
        
        result = workflow.send(:validate_analysis_result, invalid_result)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include('estimated_completion_time must be a positive number')
        expect(result[:errors]).to include('suggested_question_count must be a positive number')
      end

      it 'validates key_topics is an array' do
        invalid_result = {
          'form_purpose' => 'Valid purpose with enough content',
          'target_audience' => 'Valid audience with enough content',
          'recommended_approach' => 'feedback',
          'complexity_level' => 'moderate',
          'key_topics' => 'not an array'
        }
        
        result = workflow.send(:validate_analysis_result, invalid_result)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include('key_topics must be an array')
      end
    end

    context 'with confidence scoring' do
      it 'calculates high confidence for complete analysis' do
        complete_result = {
          'form_purpose' => 'Detailed form purpose with sufficient information for analysis',
          'target_audience' => 'Well-defined target audience description with specific details',
          'recommended_approach' => 'feedback',
          'complexity_level' => 'moderate',
          'estimated_completion_time' => 5,
          'suggested_question_count' => 8,
          'key_topics' => ['topic1', 'topic2', 'topic3'],
          'requires_branching_logic' => false
        }
        
        confidence = workflow.send(:calculate_analysis_confidence, complete_result)
        expect(confidence).to be >= 80.0
      end

      it 'calculates lower confidence for incomplete analysis' do
        incomplete_result = {
          'form_purpose' => 'Short',
          'target_audience' => 'Brief',
          'recommended_approach' => 'other',
          'complexity_level' => 'simple'
        }
        
        confidence = workflow.send(:calculate_analysis_confidence, incomplete_result)
        expect(confidence).to be < 50.0
      end

      it 'awards points for detailed key topics' do
        result_with_topics = {
          'form_purpose' => 'Detailed purpose',
          'target_audience' => 'Detailed audience',
          'recommended_approach' => 'feedback',
          'complexity_level' => 'moderate',
          'key_topics' => ['topic1', 'topic2', 'topic3', 'topic4']
        }
        
        result_without_topics = result_with_topics.except('key_topics')
        
        confidence_with = workflow.send(:calculate_analysis_confidence, result_with_topics)
        confidence_without = workflow.send(:calculate_analysis_confidence, result_without_topics)
        
        expect(confidence_with).to be > confidence_without
      end

      it 'awards points for realistic estimates' do
        realistic_result = {
          'form_purpose' => 'Detailed purpose',
          'target_audience' => 'Detailed audience',
          'recommended_approach' => 'feedback',
          'complexity_level' => 'moderate',
          'estimated_completion_time' => 5,
          'suggested_question_count' => 8
        }
        
        unrealistic_result = realistic_result.merge({
          'estimated_completion_time' => 100,
          'suggested_question_count' => 50
        })
        
        realistic_confidence = workflow.send(:calculate_analysis_confidence, realistic_result)
        unrealistic_confidence = workflow.send(:calculate_analysis_confidence, unrealistic_result)
        
        expect(realistic_confidence).to be > unrealistic_confidence
      end
    end
  end

  describe '#generate_structured_questions' do
    let(:workflow) { described_class.new }
    let(:content_result) do
      {
        content: prompt_content,
        source_type: 'prompt',
        word_count: 20,
        metadata: { processed_at: Time.current.iso8601 }
      }
    end
    let(:analysis_result) do
      {
        'form_purpose' => 'Collect customer feedback for restaurant improvement',
        'target_audience' => 'Restaurant customers who have dined recently',
        'recommended_approach' => 'feedback',
        'complexity_level' => 'moderate',
        'estimated_completion_time' => 5,
        'suggested_question_count' => 1, # Match the number of questions in test structure
        'key_topics' => ['food quality', 'service', 'ambiance'],
        'requires_branching_logic' => false
      }
    end

    describe 'helper methods for form generation' do
      describe '#build_comprehensive_form_prompt' do
        it 'builds a detailed prompt with all required elements' do
          prompt = workflow.send(
            :build_comprehensive_form_prompt,
            prompt_content, 'Test purpose', 'Test audience', 'feedback', 
            8, ['topic1', 'topic2'], 'moderate', ['text_short', 'email']
          )
          
          expect(prompt).to include('Test purpose')
          expect(prompt).to include('Test audience')
          expect(prompt).to include('feedback')
          expect(prompt).to include('text_short, email')
          expect(prompt).to include('STRICT JSON Schema')
        end
      end

      describe '#validate_generated_structure' do
        let(:valid_structure) do
          {
            'form_meta' => {
              'title' => 'Customer Feedback Form',
              'description' => 'Help us improve your dining experience',
              'category' => 'customer_feedback',
              'instructions' => 'Please answer all questions honestly'
            },
            'questions' => [
              {
                'title' => 'How was your overall experience?',
                'description' => 'Rate your overall satisfaction',
                'question_type' => 'rating',
                'required' => true,
                'question_config' => { 'min' => 1, 'max' => 5 },
                'position_rationale' => 'Opening with an easy rating question to build engagement'
              }
            ],
            'form_settings' => {
              'one_question_per_page' => false,
              'show_progress_bar' => true,
              'allow_multiple_submissions' => false,
              'collect_email' => false,
              'thank_you_message' => 'Thank you for your feedback!'
            }
          }
        end

        it 'validates a properly structured form' do
          result = workflow.send(:validate_generated_structure, valid_structure, analysis_result)
          expect(result[:valid]).to be true
          expect(result[:errors]).to be_empty
        end

        it 'rejects structure with invalid question type' do
          invalid_structure = valid_structure.deep_dup
          invalid_structure['questions'][0]['question_type'] = 'invalid_type'
          
          result = workflow.send(:validate_generated_structure, invalid_structure, analysis_result)
          expect(result[:valid]).to be false
          expect(result[:errors]).to include(match(/invalid question_type/))
        end

        it 'rejects structure with missing position_rationale' do
          invalid_structure = valid_structure.deep_dup
          invalid_structure['questions'][0]['position_rationale'] = ''
          
          result = workflow.send(:validate_generated_structure, invalid_structure, analysis_result)
          expect(result[:valid]).to be false
          expect(result[:errors]).to include(match(/position_rationale must be provided/))
        end
      end

      describe '#apply_generation_optimizations' do
        let(:basic_structure) do
          {
            'form_meta' => { 'title' => 'Test Form' },
            'questions' => [
              {
                'title' => 'Email',
                'question_type' => 'email',
                'required' => true,
                'question_config' => {},
                'position_rationale' => 'Email for contact'
              },
              {
                'title' => 'Name',
                'question_type' => 'text_short',
                'required' => true,
                'question_config' => {},
                'position_rationale' => 'Name for personalization'
              }
            ],
            'form_settings' => {
              'one_question_per_page' => false,
              'show_progress_bar' => false,
              'allow_multiple_submissions' => false,
              'collect_email' => false,
              'thank_you_message' => 'Thank you!'
            }
          }
        end

        it 'optimizes question ordering and configurations' do
          result = workflow.send(:apply_generation_optimizations, basic_structure, analysis_result)
          
          # Should add position numbers
          expect(result['questions'][0]['position']).to eq(1)
          expect(result['questions'][1]['position']).to eq(2)
          
          # Should enhance question configs
          expect(result['questions'].find { |q| q['question_type'] == 'email' }['question_config']['validation']).to eq('email')
          expect(result['questions'].find { |q| q['question_type'] == 'text_short' }['question_config']['max_length']).to eq(100)
          
          # Should add generation metadata
          expect(result['generation_metadata']).to be_present
          expect(result['generation_metadata'][:optimization_applied]).to be true
        end
      end

      describe '#get_available_question_types' do
        it 'returns FormQuestion::QUESTION_TYPES' do
          types = workflow.send(:get_available_question_types)
          expect(types).to eq(FormQuestion::QUESTION_TYPES)
          expect(types).to include('text_short', 'email', 'rating', 'multiple_choice')
        end
      end
    end
  end

  describe '#validate_and_clean_structure task' do
    let(:workflow) { described_class.new }
    let(:analysis_result) do
      {
        'form_purpose' => 'Collect customer feedback',
        'target_audience' => 'Restaurant customers',
        'recommended_approach' => 'feedback',
        'complexity_level' => 'moderate',
        'estimated_completion_time' => 5,
        'suggested_question_count' => 3
      }
    end

    context 'with valid form structure' do
      let(:valid_structure) do
        {
          'form_meta' => {
            'title' => 'Customer Feedback Form',
            'description' => 'Help us improve your dining experience',
            'category' => 'customer_feedback',
            'instructions' => 'Please answer all questions honestly'
          },
          'questions' => [
            {
              'title' => 'How was your overall experience?',
              'description' => 'Rate your overall satisfaction',
              'question_type' => 'rating',
              'required' => true,
              'question_config' => { 'min' => 1, 'max' => 5 },
              'position_rationale' => 'Opening with an easy rating question to build engagement'
            },
            {
              'title' => 'What did you like most?',
              'description' => 'Tell us about the highlights',
              'question_type' => 'text_long',
              'required' => false,
              'question_config' => { 'max_length' => 500 },
              'position_rationale' => 'Follow-up question to gather specific positive feedback'
            },
            {
              'title' => 'Your email for follow-up',
              'description' => 'Optional - for follow-up communication',
              'question_type' => 'email',
              'required' => false,
              'question_config' => { 'validation' => 'email' },
              'position_rationale' => 'Email at the end to avoid early abandonment'
            }
          ],
          'form_settings' => {
            'one_question_per_page' => false,
            'show_progress_bar' => true,
            'allow_multiple_submissions' => false,
            'collect_email' => false,
            'thank_you_message' => 'Thank you for your feedback!'
          }
        }
      end

      it 'validates structure successfully' do
        result = workflow.send(:validate_form_structure, valid_structure)
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
      end

      it 'applies business rules successfully' do
        result = workflow.send(:apply_business_rules, valid_structure)
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
      end

      it 'cleans and normalizes structure correctly' do
        cleaned = workflow.send(:clean_and_normalize_structure, valid_structure, analysis_result)
        
        expect(cleaned['form_meta']['title']).to eq('Customer Feedback Form')
        expect(cleaned['form_meta']['estimated_completion_time']).to eq(5)
        expect(cleaned['questions'][0]['position']).to eq(1)
        expect(cleaned['questions'][1]['position']).to eq(2)
        expect(cleaned['questions'][2]['position']).to eq(3)
      end

      it 'enhances question configurations' do
        enhanced = workflow.send(:enhance_question_configurations, valid_structure)
        
        # Check rating question enhancements
        rating_question = enhanced['questions'].find { |q| q['question_type'] == 'rating' }
        expect(rating_question['question_config']['labels']).to be_present
        
        # Check text_long question enhancements
        text_question = enhanced['questions'].find { |q| q['question_type'] == 'text_long' }
        expect(text_question['question_config']['min_length']).to eq(10)
        expect(text_question['question_config']['placeholder']).to be_present
        
        # Check email question enhancements
        email_question = enhanced['questions'].find { |q| q['question_type'] == 'email' }
        expect(email_question['question_config']['placeholder']).to be_present
      end

      it 'validates final structure integrity' do
        result = workflow.send(:validate_final_structure, valid_structure)
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
      end
    end

    context 'with invalid form structure' do
      it 'rejects structure with missing form_meta' do
        invalid_structure = { 'questions' => [], 'form_settings' => {} }
        result = workflow.send(:validate_form_structure, invalid_structure)
        
        expect(result[:valid]).to be false
        expect(result[:errors]).to include('form_meta section is required and must be a hash')
      end

      it 'rejects structure with invalid questions array' do
        invalid_structure = {
          'form_meta' => { 'title' => 'Test', 'category' => 'other' },
          'questions' => 'not an array',
          'form_settings' => {}
        }
        result = workflow.send(:validate_form_structure, invalid_structure)
        
        expect(result[:valid]).to be false
        expect(result[:errors]).to include('questions must be an array')
      end

      it 'rejects structure with missing form_settings' do
        invalid_structure = {
          'form_meta' => { 'title' => 'Test', 'category' => 'other' },
          'questions' => []
        }
        result = workflow.send(:validate_form_structure, invalid_structure)
        
        expect(result[:valid]).to be false
        expect(result[:errors]).to include('form_settings section is required and must be a hash')
      end
    end

    context 'with business rules validation' do
      let(:valid_structure) do
        {
          'form_meta' => {
            'title' => 'Customer Feedback Form',
            'description' => 'Help us improve your dining experience',
            'category' => 'customer_feedback',
            'instructions' => 'Please answer all questions honestly'
          },
          'questions' => [
            {
              'title' => 'How was your overall experience?',
              'description' => 'Rate your overall satisfaction',
              'question_type' => 'rating',
              'required' => true,
              'question_config' => { 'min' => 1, 'max' => 5 },
              'position_rationale' => 'Opening with an easy rating question to build engagement'
            }
          ],
          'form_settings' => {
            'one_question_per_page' => false,
            'show_progress_bar' => true,
            'allow_multiple_submissions' => false,
            'collect_email' => false,
            'thank_you_message' => 'Thank you for your feedback!'
          }
        }
      end

      it 'rejects forms with too many questions' do
        large_structure = valid_structure.deep_dup
        large_structure['questions'] = Array.new(25) do |i|
          {
            'title' => "Question #{i + 1}",
            'question_type' => 'text_short',
            'required' => false,
            'question_config' => {},
            'position_rationale' => 'Test question'
          }
        end
        
        result = workflow.send(:apply_business_rules, large_structure)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include('too many questions (25). Maximum 20 questions allowed')
      end

      it 'rejects forms with invalid category' do
        invalid_structure = valid_structure.deep_dup
        invalid_structure['form_meta']['category'] = 'invalid_category'
        
        result = workflow.send(:apply_business_rules, invalid_structure)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include(match(/invalid category: invalid_category/))
      end

      it 'warns about missing email in lead generation forms' do
        lead_structure = valid_structure.deep_dup
        lead_structure['form_meta']['category'] = 'lead_generation'
        # Remove email question
        lead_structure['questions'] = lead_structure['questions'].reject { |q| q['question_type'] == 'email' }
        
        result = workflow.send(:apply_business_rules, lead_structure)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include('lead generation forms should include an email question')
      end
    end

    context 'with data cleaning and normalization' do
      let(:valid_structure) do
        {
          'form_meta' => {
            'title' => 'Customer Feedback Form',
            'description' => 'Help us improve your dining experience',
            'category' => 'customer_feedback',
            'instructions' => 'Please answer all questions honestly'
          },
          'questions' => [
            {
              'title' => 'How was your overall experience?',
              'description' => 'Rate your overall satisfaction',
              'question_type' => 'rating',
              'required' => true,
              'question_config' => { 'min' => 1, 'max' => 5 },
              'position_rationale' => 'Opening with an easy rating question to build engagement'
            }
          ],
          'form_settings' => {
            'one_question_per_page' => false,
            'show_progress_bar' => true,
            'allow_multiple_submissions' => false,
            'collect_email' => false,
            'thank_you_message' => 'Thank you for your feedback!'
          }
        }
      end

      it 'truncates long titles and descriptions' do
        long_structure = valid_structure.deep_dup
        long_structure['form_meta']['title'] = 'A' * 100
        long_structure['form_meta']['description'] = 'B' * 300
        
        cleaned = workflow.send(:clean_and_normalize_structure, long_structure, analysis_result)
        
        expect(cleaned['form_meta']['title'].length).to eq(60)
        expect(cleaned['form_meta']['description'].length).to eq(200)
      end

      it 'adds missing position rationales' do
        structure_without_rationale = valid_structure.deep_dup
        structure_without_rationale['questions'][0].delete('position_rationale')
        
        cleaned = workflow.send(:clean_and_normalize_structure, structure_without_rationale, analysis_result)
        
        expect(cleaned['questions'][0]['position_rationale']).to be_present
        expect(cleaned['questions'][0]['position_rationale']).to include('Question 1')
      end

      it 'normalizes boolean values in form_settings' do
        structure_with_strings = valid_structure.deep_dup
        structure_with_strings['form_settings']['one_question_per_page'] = 'true'
        structure_with_strings['form_settings']['show_progress_bar'] = 'false'
        
        cleaned = workflow.send(:clean_and_normalize_structure, structure_with_strings, analysis_result)
        
        expect(cleaned['form_settings']['one_question_per_page']).to be true
        expect(cleaned['form_settings']['show_progress_bar']).to be false
      end
    end

    context 'with final structure integrity validation' do
      let(:valid_structure) do
        {
          'form_meta' => {
            'title' => 'Customer Feedback Form',
            'description' => 'Help us improve your dining experience',
            'category' => 'customer_feedback',
            'instructions' => 'Please answer all questions honestly'
          },
          'questions' => [
            {
              'title' => 'How was your overall experience?',
              'description' => 'Rate your overall satisfaction',
              'question_type' => 'rating',
              'required' => true,
              'question_config' => { 'min' => 1, 'max' => 5 },
              'position_rationale' => 'Opening with an easy rating question to build engagement',
              'position' => 1
            },
            {
              'title' => 'What did you like most?',
              'description' => 'Tell us about the highlights',
              'question_type' => 'text_long',
              'required' => false,
              'question_config' => { 'max_length' => 500 },
              'position_rationale' => 'Follow-up question to gather specific positive feedback',
              'position' => 2
            },
            {
              'title' => 'Your email for follow-up',
              'description' => 'Optional - for follow-up communication',
              'question_type' => 'email',
              'required' => false,
              'question_config' => { 'validation' => 'email' },
              'position_rationale' => 'Email at the end to avoid early abandonment',
              'position' => 3
            }
          ],
          'form_settings' => {
            'one_question_per_page' => false,
            'show_progress_bar' => true,
            'allow_multiple_submissions' => false,
            'collect_email' => false,
            'thank_you_message' => 'Thank you for your feedback!'
          }
        }
      end

      it 'detects duplicate question positions' do
        invalid_structure = valid_structure.deep_dup
        invalid_structure['questions'][0]['position'] = 1
        invalid_structure['questions'][1]['position'] = 1
        invalid_structure['questions'][2]['position'] = 2
        
        result = workflow.send(:validate_final_structure, invalid_structure)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include('duplicate question positions found')
      end

      it 'detects non-sequential question positions' do
        invalid_structure = valid_structure.deep_dup
        invalid_structure['questions'][0]['position'] = 1
        invalid_structure['questions'][1]['position'] = 3
        invalid_structure['questions'][2]['position'] = 5
        
        result = workflow.send(:validate_final_structure, invalid_structure)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include('question positions are not sequential')
      end
    end
  end

  describe '#create_optimized_form task' do
    let(:workflow) { described_class.new }
    let(:content_result) { { user: user } }
    let(:analysis_result) do
      {
        'recommended_approach' => 'feedback',
        'complexity_level' => 'moderate',
        'estimated_completion_time' => 5
      }
    end
    let(:structure_result) do
      {
        form_structure: {
          'form_meta' => {
            'title' => 'Test Form',
            'description' => 'Test Description',
            'category' => 'customer_feedback',
            'instructions' => 'Please complete this form'
          },
          'questions' => [
            {
              'title' => 'Test Question',
              'question_type' => 'text_short',
              'required' => true,
              'position' => 1,
              'question_config' => { 'max_length' => 100 },
              'position_rationale' => 'First question for engagement'
            }
          ],
          'form_settings' => {
            'one_question_per_page' => false,
            'show_progress_bar' => true,
            'thank_you_message' => 'Thank you!'
          }
        }
      }
    end

    it 'calculates generation cost correctly' do
      questions_count = 5
      cost = workflow.send(:calculate_generation_cost, questions_count)
      
      expect(cost).to eq(0.1) # 0.05 base + 5 * 0.01
    end

    it 'determines AI features based on approach' do
      features = workflow.send(:determine_ai_features, analysis_result)
      
      expect(features).to include('response_validation')
      expect(features).to include('sentiment_analysis')
      expect(features).to include('response_categorization')
    end

    it 'determines AI features for lead capture' do
      lead_analysis = analysis_result.merge('recommended_approach' => 'lead_capture')
      features = workflow.send(:determine_ai_features, lead_analysis)
      
      expect(features).to include('lead_scoring')
      expect(features).to include('intent_detection')
    end

    it 'adds dynamic followup for branching logic' do
      branching_analysis = analysis_result.merge('requires_branching_logic' => true)
      features = workflow.send(:determine_ai_features, branching_analysis)
      
      expect(features).to include('dynamic_followup')
    end

    it 'enables AI for appropriate question types' do
      expect(workflow.send(:should_enable_ai_for_question?, 'text_long')).to be true
      expect(workflow.send(:should_enable_ai_for_question?, 'email')).to be true
      expect(workflow.send(:should_enable_ai_for_question?, 'rating')).to be true
      expect(workflow.send(:should_enable_ai_for_question?, 'date')).to be false
    end

    it 'builds question AI config for text_long questions' do
      question_data = { 'question_type' => 'text_long' }
      config = workflow.send(:build_question_ai_config, question_data, true)
      
      expect(config[:sentiment_analysis]).to be true
      expect(config[:keyword_extraction]).to be true
      expect(config[:quality_scoring]).to be true
    end

    it 'builds question AI config for email questions' do
      question_data = { 'question_type' => 'email' }
      config = workflow.send(:build_question_ai_config, question_data, true)
      
      expect(config[:validation_enhancement]).to be true
      expect(config[:format_suggestions]).to be true
      expect(config[:domain_verification]).to be true
    end

    it 'returns empty config for non-AI-enhanced questions' do
      question_data = { 'question_type' => 'date' }
      config = workflow.send(:build_question_ai_config, question_data, false)
      
      expect(config).to be_empty
    end
  end

  describe 'private helper methods' do
    let(:workflow) { described_class.new }

    describe '#validate_analysis_result' do
      it 'validates a complete analysis result' do
        valid_result = {
          'form_purpose' => 'Collect customer feedback for restaurant improvement',
          'target_audience' => 'Restaurant customers who have dined recently',
          'recommended_approach' => 'feedback',
          'complexity_level' => 'moderate',
          'estimated_completion_time' => 5,
          'suggested_question_count' => 8,
          'key_topics' => ['food quality', 'service', 'ambiance'],
          'requires_branching_logic' => false
        }
        
        result = workflow.send(:validate_analysis_result, valid_result)
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
      end

      it 'rejects analysis result with missing required fields' do
        invalid_result = {
          'form_purpose' => 'Test form'
          # Missing other required fields
        }
        
        result = workflow.send(:validate_analysis_result, invalid_result)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include('target_audience is required')
        expect(result[:errors]).to include('recommended_approach is required')
      end

      it 'rejects analysis result with invalid enum values' do
        invalid_result = {
          'form_purpose' => 'Test form purpose that is long enough',
          'target_audience' => 'Test audience that is long enough',
          'recommended_approach' => 'invalid_approach',
          'complexity_level' => 'invalid_complexity'
        }
        
        result = workflow.send(:validate_analysis_result, invalid_result)
        expect(result[:valid]).to be false
        expect(result[:errors]).to include('recommended_approach must be one of: survey, lead_capture, feedback, registration, assessment, other')
        expect(result[:errors]).to include('complexity_level must be one of: simple, moderate, complex')
      end
    end

    describe '#calculate_analysis_confidence' do
      it 'calculates high confidence for complete analysis' do
        complete_result = {
          'form_purpose' => 'Detailed form purpose with sufficient information',
          'target_audience' => 'Well-defined target audience description',
          'recommended_approach' => 'feedback',
          'complexity_level' => 'moderate',
          'estimated_completion_time' => 5,
          'suggested_question_count' => 8,
          'key_topics' => ['topic1', 'topic2', 'topic3'],
          'requires_branching_logic' => false
        }
        
        confidence = workflow.send(:calculate_analysis_confidence, complete_result)
        expect(confidence).to be >= 80.0
      end

      it 'calculates lower confidence for incomplete analysis' do
        incomplete_result = {
          'form_purpose' => 'Short',
          'target_audience' => 'Brief',
          'recommended_approach' => 'other',
          'complexity_level' => 'simple'
        }
        
        confidence = workflow.send(:calculate_analysis_confidence, incomplete_result)
        expect(confidence).to be < 50.0
      end
    end

    describe '#validate_ai_credits' do
      it 'returns valid result for user with available credits' do
        result = workflow.send(:validate_ai_credits, user)
        
        expect(result[:valid]).to be true
        expect(result[:remaining]).to eq(10.0)
      end

      it 'returns invalid result for user who exceeded limits' do
        user.update!(ai_credits_used: 10.0)
        result = workflow.send(:validate_ai_credits, user)
        
        expect(result[:valid]).to be false
        expect(result[:message]).to include("Monthly AI usage limit exceeded")
      end
    end

    describe '#validate_content_length' do
      it 'validates content within acceptable range' do
        result = workflow.send(:validate_content_length, 100)
        expect(result[:valid]).to be true
      end

      it 'rejects content that is too short' do
        result = workflow.send(:validate_content_length, 5)
        expect(result[:valid]).to be false
        expect(result[:message]).to include("Content too short")
      end

      it 'rejects content that is too long' do
        result = workflow.send(:validate_content_length, 6000)
        expect(result[:valid]).to be false
        expect(result[:message]).to include("Content too long")
      end
    end

    describe '#process_prompt_input' do
      it 'processes valid prompt text' do
        result = workflow.send(:process_prompt_input, prompt_content, metadata)
        
        expect(result[:success]).to be true
        expect(result[:content]).to eq(prompt_content.strip)
        expect(result[:word_count]).to be > 0
      end

      it 'rejects empty prompt' do
        result = workflow.send(:process_prompt_input, "", metadata)
        
        expect(result[:success]).to be false
        expect(result[:message]).to include("cannot be empty")
      end
    end

    describe '#calculate_estimated_generation_cost' do
      it 'calculates cost based on word count' do
        cost_100_words = workflow.send(:calculate_estimated_generation_cost, 100)
        cost_1000_words = workflow.send(:calculate_estimated_generation_cost, 1000)
        
        expect(cost_1000_words).to be > cost_100_words
        expect(cost_100_words).to be > 0
      end

      it 'includes complexity multiplier in cost calculation' do
        simple_cost = workflow.send(:calculate_estimated_generation_cost, 100)
        complex_cost = workflow.send(:calculate_estimated_generation_cost, 2000)
        
        expect(complex_cost).to be > simple_cost
      end

      it 'estimates question count and includes in cost' do
        # Test that longer content results in higher estimated question count and cost
        short_content_cost = workflow.send(:calculate_estimated_generation_cost, 200)
        long_content_cost = workflow.send(:calculate_estimated_generation_cost, 3000)
        
        expect(long_content_cost).to be > short_content_cost
      end
    end

    describe '#safe_db_operation' do
      it 'handles ActiveRecord::RecordInvalid exceptions' do
        result = workflow.send(:safe_db_operation) do
          raise ActiveRecord::RecordInvalid.new(Form.new)
        end
        
        expect(result[:error]).to be true
        expect(result[:type]).to eq('validation_error')
        expect(result[:message]).to include('Database validation failed')
      end

      it 'handles ActiveRecord::RecordNotSaved exceptions' do
        result = workflow.send(:safe_db_operation) do
          raise ActiveRecord::RecordNotSaved.new('Save failed')
        end
        
        expect(result[:error]).to be true
        expect(result[:type]).to eq('save_error')
        expect(result[:message]).to include('Failed to save record')
      end

      it 'handles general StandardError exceptions' do
        expect(Rails.logger).to receive(:error).with('Database operation failed: General error')
        
        result = workflow.send(:safe_db_operation) do
          raise StandardError, 'General error'
        end
        
        expect(result[:error]).to be true
        expect(result[:type]).to eq('database_error')
        expect(result[:message]).to eq('Database operation failed')
      end

      it 'returns successful result when no exception occurs' do
        result = workflow.send(:safe_db_operation) do
          { success: true, data: 'test' }
        end
        
        expect(result[:success]).to be true
        expect(result[:data]).to eq('test')
      end
    end

    describe '#track_ai_usage' do
      let(:context) { {} }

      it 'tracks AI usage in context' do
        workflow.send(:track_ai_usage, context, 0.05, 'content_analysis')
        
        expect(context[:ai_usage]).to be_an(Array)
        expect(context[:ai_usage].length).to eq(1)
        expect(context[:ai_usage][0][:operation]).to eq('content_analysis')
        expect(context[:ai_usage][0][:cost]).to eq(0.05)
        expect(context[:ai_usage][0][:timestamp]).to be_present
      end

      it 'accumulates multiple AI usage entries' do
        workflow.send(:track_ai_usage, context, 0.02, 'analysis')
        workflow.send(:track_ai_usage, context, 0.08, 'generation')
        
        expect(context[:ai_usage].length).to eq(2)
        expect(context[:ai_usage][0][:operation]).to eq('analysis')
        expect(context[:ai_usage][1][:operation]).to eq('generation')
      end

      it 'logs AI usage for monitoring' do
        expect(Rails.logger).to receive(:info).with('AI Usage tracked: test_operation - Cost: 0.1')
        
        workflow.send(:track_ai_usage, context, 0.1, 'test_operation')
      end
    end

    describe '#format_success_result' do
      it 'formats successful results with timestamp' do
        data = { form_id: 123, questions_count: 5 }
        result = workflow.send(:format_success_result, data)
        
        expect(result[:success]).to be true
        expect(result[:form_id]).to eq(123)
        expect(result[:questions_count]).to eq(5)
        expect(result[:timestamp]).to be_present
        expect(Time.parse(result[:timestamp])).to be_within(1.second).of(Time.current)
      end
    end

    describe '#format_error_result' do
      it 'formats error results with required fields' do
        result = workflow.send(:format_error_result, 'Test error', 'test_error', { detail: 'extra info' })
        
        expect(result[:success]).to be false
        expect(result[:error]).to be true
        expect(result[:message]).to eq('Test error')
        expect(result[:error_type]).to eq('test_error')
        expect(result[:detail]).to eq('extra info')
        expect(result[:timestamp]).to be_present
      end
    end

    describe '#validate_required_inputs' do
      it 'passes validation when all required inputs are present' do
        context = { user_id: 1, content_input: 'test', input_type: 'prompt' }
        
        expect {
          workflow.send(:validate_required_inputs, context, :user_id, :content_input, :input_type)
        }.not_to raise_error
      end

      it 'raises error when required inputs are missing' do
        context = { user_id: 1 }
        
        expect {
          workflow.send(:validate_required_inputs, context, :user_id, :content_input, :input_type)
        }.to raise_error(ArgumentError, 'Missing required inputs: content_input, input_type')
      end

      it 'raises error when required inputs are blank' do
        context = { user_id: 1, content_input: '', input_type: nil }
        
        expect {
          workflow.send(:validate_required_inputs, context, :user_id, :content_input, :input_type)
        }.to raise_error(ArgumentError, 'Missing required inputs: content_input, input_type')
      end
    end

    describe 'form generation prompt building' do
      it 'builds comprehensive prompt with all required elements' do
        prompt = workflow.send(
          :build_comprehensive_form_prompt,
          'Test content', 'Test purpose', 'Test audience', 'feedback',
          8, ['topic1', 'topic2'], 'moderate', ['text_short', 'email']
        )
        
        expect(prompt).to include('Test purpose')
        expect(prompt).to include('Test audience')
        expect(prompt).to include('feedback')
        expect(prompt).to include('text_short, email')
        expect(prompt).to include('STRICT JSON Schema')
        expect(prompt).to include('Question Configuration Requirements')
        expect(prompt).to include('Position Rationale Guidelines')
      end

      it 'determines form category correctly' do
        expect(workflow.send(:determine_form_category, 'lead_capture')).to eq('lead_generation')
        expect(workflow.send(:determine_form_category, 'feedback')).to eq('customer_feedback')
        expect(workflow.send(:determine_form_category, 'survey')).to eq('customer_feedback')
        expect(workflow.send(:determine_form_category, 'assessment')).to eq('market_research')
        expect(workflow.send(:determine_form_category, 'registration')).to eq('event_registration')
        expect(workflow.send(:determine_form_category, 'other')).to eq('other')
      end

      it 'constrains question count to reasonable bounds' do
        # Test that extremely high suggested counts are capped
        prompt = workflow.send(
          :build_comprehensive_form_prompt,
          'Test content', 'Test purpose', 'Test audience', 'feedback',
          50, ['topic1'], 'simple', ['text_short']
        )
        
        expect(prompt).to include('exactly 20 questions') # Should be capped at 20
        
        # Test that extremely low suggested counts are raised
        prompt = workflow.send(
          :build_comprehensive_form_prompt,
          'Test content', 'Test purpose', 'Test audience', 'feedback',
          2, ['topic1'], 'simple', ['text_short']
        )
        
        expect(prompt).to include('exactly 5 questions') # Should be raised to 5
      end
    end

    describe 'form optimization methods' do
      let(:basic_questions) do
        [
          { 'question_type' => 'email', 'title' => 'Email', 'required' => true },
          { 'question_type' => 'text_short', 'title' => 'Name', 'required' => true },
          { 'question_type' => 'rating', 'title' => 'Rating', 'required' => false },
          { 'question_type' => 'text_long', 'title' => 'Comments', 'required' => false }
        ]
      end

      it 'optimizes question ordering for better completion rates' do
        optimized = workflow.send(:optimize_question_ordering, basic_questions)
        
        # Easy questions should come first
        expect(optimized[0]['question_type']).to eq('text_short')
        expect(optimized[1]['question_type']).to eq('rating')
        
        # Sensitive questions should come later
        email_position = optimized.find_index { |q| q['question_type'] == 'email' }
        expect(email_position).to be > 1
      end

      it 'calculates question priority correctly' do
        email_question = { 'question_type' => 'email', 'required' => true }
        text_question = { 'question_type' => 'text_short', 'required' => false }
        
        email_priority = workflow.send(:calculate_question_priority, email_question, 0)
        text_priority = workflow.send(:calculate_question_priority, text_question, 0)
        
        # Email should have higher priority score (later position)
        expect(email_priority).to be > text_priority
      end

      it 'enhances question config by type' do
        email_config = workflow.send(:enhance_question_config_by_type, {}, 'email')
        expect(email_config['validation']).to eq('email')
        expect(email_config['placeholder']).to be_present
        
        rating_config = workflow.send(:enhance_question_config_by_type, {}, 'rating')
        expect(rating_config['min']).to eq(1)
        expect(rating_config['max']).to eq(5)
        expect(rating_config['labels']).to be_present
        
        text_config = workflow.send(:enhance_question_config_by_type, {}, 'text_long')
        expect(text_config['max_length']).to eq(1000)
        expect(text_config['min_length']).to eq(10)
      end

      it 'optimizes form settings based on complexity' do
        complex_analysis = { 'complexity_level' => 'complex', 'recommended_approach' => 'feedback' }
        base_settings = { 'thank_you_message' => 'Thanks!' }
        
        optimized = workflow.send(:optimize_form_settings, base_settings, complex_analysis, 12)
        
        expect(optimized['one_question_per_page']).to be true
        expect(optimized['show_progress_bar']).to be true
      end

      it 'calculates estimated completion time based on question types' do
        questions = [
          { 'question_type' => 'text_short' },
          { 'question_type' => 'text_long' },
          { 'question_type' => 'rating' },
          { 'question_type' => 'email' }
        ]
        
        time = workflow.send(:calculate_estimated_completion_time, questions)
        
        expect(time).to be > 1 # Should be more than base time
        expect(time).to be_a(Float)
      end

      it 'calculates form generation cost with retries' do
        base_cost = workflow.send(:calculate_form_generation_cost, 5, 1)
        retry_cost = workflow.send(:calculate_form_generation_cost, 5, 3)
        
        expect(retry_cost).to be > base_cost
        expect(retry_cost - base_cost).to be_within(0.001).of(0.04) # 2 additional retries * 0.02
      end
    end
  end
end