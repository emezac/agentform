# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Form Generation Integration', type: :integration do
  let(:user) { create(:user, ai_credits_used: 0.0, monthly_ai_limit: 10.0) }
  let(:prompt_content) { "I need a customer feedback form for my restaurant to collect reviews and suggestions from diners. I want to know about food quality, service experience, ambiance, and get their contact information for follow-up." }
  let(:metadata) { { source: 'web_interface', timestamp: Time.current.iso8601 } }

  describe 'End-to-end form generation from prompt input' do
    let(:mock_analysis_response) do
      {
        'form_purpose' => 'Collect customer feedback for restaurant improvement',
        'target_audience' => 'Restaurant customers who have dined recently',
        'data_collection_goal' => 'Improve service quality and menu offerings',
        'recommended_approach' => 'feedback',
        'estimated_completion_time' => 5,
        'complexity_level' => 'moderate',
        'suggested_question_count' => 6,
        'key_topics' => ['food quality', 'service', 'ambiance', 'contact'],
        'requires_branching_logic' => false,
        'form_category' => 'customer_feedback',
        'priority_data_points' => ['satisfaction', 'recommendations', 'contact_info'],
        'user_experience_considerations' => {
          'mobile_optimization' => true,
          'progress_indication' => true,
          'one_question_per_page' => false,
          'estimated_abandonment_risk' => 'low'
        }
      }.to_json
    end

    let(:mock_generation_response) do
      {
        'form_meta' => {
          'title' => 'Restaurant Feedback Form',
          'description' => 'Help us improve your dining experience',
          'category' => 'customer_feedback',
          'instructions' => 'Please share your honest feedback about your recent visit'
        },
        'questions' => [
          {
            'title' => 'How would you rate your overall experience?',
            'description' => 'Please rate your overall satisfaction with your visit',
            'question_type' => 'rating',
            'required' => true,
            'question_config' => { 'min' => 1, 'max' => 5, 'labels' => { 'min' => 'Poor', 'max' => 'Excellent' } },
            'position_rationale' => 'Starting with an easy rating question to build engagement and set positive tone'
          },
          {
            'title' => 'How was the food quality?',
            'description' => 'Rate the taste, presentation, and freshness of your meal',
            'question_type' => 'rating',
            'required' => true,
            'question_config' => { 'min' => 1, 'max' => 5, 'labels' => { 'min' => 'Poor', 'max' => 'Excellent' } },
            'position_rationale' => 'Food quality is core to restaurant experience, placed early for importance'
          },
          {
            'title' => 'How would you rate our service?',
            'description' => 'Consider friendliness, attentiveness, and speed of service',
            'question_type' => 'rating',
            'required' => true,
            'question_config' => { 'min' => 1, 'max' => 5, 'labels' => { 'min' => 'Poor', 'max' => 'Excellent' } },
            'position_rationale' => 'Service rating follows food quality as another core experience metric'
          },
          {
            'title' => 'What did you think of the ambiance?',
            'description' => 'Rate the atmosphere, cleanliness, and comfort of our restaurant',
            'question_type' => 'rating',
            'required' => false,
            'question_config' => { 'min' => 1, 'max' => 5, 'labels' => { 'min' => 'Poor', 'max' => 'Excellent' } },
            'position_rationale' => 'Ambiance is important but optional, placed after core service metrics'
          },
          {
            'title' => 'Any additional comments or suggestions?',
            'description' => 'Please share any specific feedback or suggestions for improvement',
            'question_type' => 'text_long',
            'required' => false,
            'question_config' => { 'max_length' => 1000, 'min_length' => 10, 'placeholder' => 'Share your thoughts...' },
            'position_rationale' => 'Open-ended feedback after structured ratings to capture detailed insights'
          },
          {
            'title' => 'Your email for follow-up',
            'description' => 'Optional - we may reach out to address any concerns or thank you',
            'question_type' => 'email',
            'required' => false,
            'question_config' => { 'validation' => 'email', 'placeholder' => 'your@email.com' },
            'position_rationale' => 'Email placed at end to avoid early abandonment while still capturing contact info'
          }
        ],
        'form_settings' => {
          'one_question_per_page' => false,
          'show_progress_bar' => true,
          'allow_multiple_submissions' => false,
          'collect_email' => false,
          'thank_you_message' => 'Thank you for your valuable feedback! We appreciate your time.'
        }
      }.to_json
    end

    before do
      # Mock LLM responses for consistent testing
      allow_any_instance_of(SuperAgent::LlmInterface).to receive(:call).and_return(mock_analysis_response, mock_generation_response)
    end

    it 'successfully generates a complete form from prompt input' do
      workflow = Forms::AiFormGenerationWorkflow.new

      # Execute the complete workflow
      result = workflow.execute(
        user_id: user.id,
        content_input: prompt_content,
        input_type: 'prompt',
        metadata: metadata
      )

      # Verify successful completion
      expect(result[:success]).to be true
      expect(result[:form_id]).to be_present

      # Verify form was created in database
      form = Form.find(result[:form_id])
      expect(form).to be_present
      expect(form.user).to eq(user)
      expect(form.name).to eq('Restaurant Feedback Form')
      expect(form.ai_enabled).to be true
      expect(form.status).to eq('draft')

      # Verify form metadata
      expect(form.metadata['generated_by_ai']).to be true
      expect(form.metadata['ai_cost']).to be > 0
      expect(form.metadata['content_analysis']).to be_present

      # Verify AI configuration
      expect(form.ai_configuration['enabled']).to be true
      expect(form.ai_configuration['features']).to include('sentiment_analysis')
      expect(form.ai_configuration['features']).to include('response_categorization')

      # Verify questions were created
      expect(form.form_questions.count).to eq(6)
      
      # Verify question ordering and configuration
      questions = form.form_questions.order(:position)
      
      # First question should be overall rating
      first_question = questions.first
      expect(first_question.title).to include('overall experience')
      expect(first_question.question_type).to eq('rating')
      expect(first_question.required).to be true
      expect(first_question.position).to eq(1)

      # Last question should be email
      last_question = questions.last
      expect(last_question.question_type).to eq('email')
      expect(last_question.required).to be false
      expect(last_question.position).to eq(6)

      # Verify AI enhancements on appropriate questions
      email_question = questions.find { |q| q.question_type == 'email' }
      expect(email_question.ai_enhanced).to be true
      expect(email_question.ai_config['validation_enhancement']).to be true

      text_question = questions.find { |q| q.question_type == 'text_long' }
      expect(text_question.ai_enhanced).to be true
      expect(text_question.ai_config['sentiment_analysis']).to be true

      # Verify user credits were deducted
      user.reload
      expect(user.ai_credits_used).to be > 0
      expect(user.ai_credits_used).to eq(form.metadata['ai_cost'])
    end

    it 'handles workflow execution with insufficient credits' do
      # Set user to have insufficient credits
      user.update!(ai_credits_used: 9.95, monthly_ai_limit: 10.0)

      workflow = Forms::AiFormGenerationWorkflow.new

      result = workflow.execute(
        user_id: user.id,
        content_input: prompt_content,
        input_type: 'prompt',
        metadata: metadata
      )

      # Verify failure due to insufficient credits
      expect(result[:success]).to be false
      expect(result[:error_type]).to eq('credit_limit_exceeded')
      expect(result[:message]).to include('Monthly AI usage limit exceeded')

      # Verify no form was created
      expect(Form.where(user: user).count).to eq(0)

      # Verify credits were not deducted
      user.reload
      expect(user.ai_credits_used).to eq(9.95)
    end

    it 'handles content that is too short' do
      short_content = "Too short"

      workflow = Forms::AiFormGenerationWorkflow.new

      result = workflow.execute(
        user_id: user.id,
        content_input: short_content,
        input_type: 'prompt',
        metadata: metadata
      )

      expect(result[:success]).to be false
      expect(result[:error_type]).to eq('content_length_error')
      expect(result[:message]).to include('Content too short')
      expect(result[:word_count]).to eq(2)
    end

    it 'handles content that is too long' do
      long_content = "word " * 5001

      workflow = Forms::AiFormGenerationWorkflow.new

      result = workflow.execute(
        user_id: user.id,
        content_input: long_content.strip,
        input_type: 'prompt',
        metadata: metadata
      )

      expect(result[:success]).to be false
      expect(result[:error_type]).to eq('content_length_error')
      expect(result[:message]).to include('Content too long')
      expect(result[:word_count]).to eq(5001)
    end
  end

  describe 'Document upload and processing integration' do
    let(:document_content) { "Restaurant Feedback Requirements\n\nWe need to collect customer feedback about their dining experience including food quality, service satisfaction, ambiance rating, and contact information for follow-up communication." }
    let(:mock_document) { create_test_document('feedback_requirements.txt', 'text/plain', document_content) }

    before do
      # Mock successful document processing
      allow_any_instance_of(Ai::DocumentProcessor).to receive(:process).and_return({
        success: true,
        content: document_content,
        source_type: 'text_document',
        metadata: {
          file_name: 'feedback_requirements.txt',
          word_count: 25,
          line_count: 3,
          content_type: 'text/plain'
        }
      })

      # Mock LLM responses
      allow_any_instance_of(SuperAgent::LlmInterface).to receive(:call).and_return(mock_analysis_response, mock_generation_response)
    end

    it 'successfully processes document and generates form' do
      workflow = Forms::AiFormGenerationWorkflow.new

      result = workflow.execute(
        user_id: user.id,
        content_input: mock_document,
        input_type: 'document',
        metadata: metadata
      )

      expect(result[:success]).to be true
      expect(result[:form_id]).to be_present

      # Verify form was created with document source metadata
      form = Form.find(result[:form_id])
      expect(form.metadata['content_analysis']).to be_present
      expect(form.form_questions.count).to eq(6)

      # Verify user credits were deducted
      user.reload
      expect(user.ai_credits_used).to be > 0
    end

    it 'handles document processing failures' do
      # Mock document processing failure
      allow_any_instance_of(Ai::DocumentProcessor).to receive(:process).and_return({
        success: false,
        errors: ['File format not supported', 'File corrupted']
      })

      workflow = Forms::AiFormGenerationWorkflow.new

      result = workflow.execute(
        user_id: user.id,
        content_input: mock_document,
        input_type: 'document',
        metadata: metadata
      )

      expect(result[:success]).to be false
      expect(result[:error_type]).to eq('document_processing_error')
      expect(result[:message]).to include('Document processing failed')
      expect(result[:errors]).to include('File format not supported')

      # Verify no form was created
      expect(Form.where(user: user).count).to eq(0)
    end

    it 'handles document processing exceptions' do
      # Mock document processing exception
      allow_any_instance_of(Ai::DocumentProcessor).to receive(:process).and_raise(StandardError, 'Processing failed')

      workflow = Forms::AiFormGenerationWorkflow.new

      result = workflow.execute(
        user_id: user.id,
        content_input: mock_document,
        input_type: 'document',
        metadata: metadata
      )

      expect(result[:success]).to be false
      expect(result[:error_type]).to eq('document_processing_exception')
      expect(result[:message]).to include('Failed to process document')
    end
  end

  describe 'Database transaction integrity and rollback scenarios' do
    before do
      allow_any_instance_of(SuperAgent::LlmInterface).to receive(:call).and_return(mock_analysis_response, mock_generation_response)
    end

    it 'rolls back transaction when form creation fails' do
      # Mock form creation failure
      allow(Form).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(Form.new))

      workflow = Forms::AiFormGenerationWorkflow.new

      result = workflow.execute(
        user_id: user.id,
        content_input: prompt_content,
        input_type: 'prompt',
        metadata: metadata
      )

      expect(result[:success]).to be false
      expect(result[:error_type]).to eq('validation_error')

      # Verify no form or questions were created
      expect(Form.where(user: user).count).to eq(0)
      expect(FormQuestion.joins(:form).where(forms: { user: user }).count).to eq(0)

      # Verify user credits were not deducted
      user.reload
      expect(user.ai_credits_used).to eq(0.0)
    end

    it 'rolls back transaction when question creation fails' do
      # Allow form creation but fail on question creation
      allow(FormQuestion).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(FormQuestion.new))

      workflow = Forms::AiFormGenerationWorkflow.new

      result = workflow.execute(
        user_id: user.id,
        content_input: prompt_content,
        input_type: 'prompt',
        metadata: metadata
      )

      expect(result[:success]).to be false

      # Verify no form or questions were created (transaction rolled back)
      expect(Form.where(user: user).count).to eq(0)
      expect(FormQuestion.joins(:form).where(forms: { user: user }).count).to eq(0)

      # Verify user credits were not deducted
      user.reload
      expect(user.ai_credits_used).to eq(0.0)
    end

    it 'rolls back transaction when credit deduction fails' do
      # Mock credit deduction failure
      allow(user).to receive(:increment!).and_raise(ActiveRecord::RecordNotSaved.new('Credit update failed'))
      allow(User).to receive(:find).and_return(user)

      workflow = Forms::AiFormGenerationWorkflow.new

      result = workflow.execute(
        user_id: user.id,
        content_input: prompt_content,
        input_type: 'prompt',
        metadata: metadata
      )

      expect(result[:success]).to be false

      # Verify no form or questions were created (transaction rolled back)
      expect(Form.where(user: user).count).to eq(0)
      expect(FormQuestion.joins(:form).where(forms: { user: user }).count).to eq(0)
    end

    it 'maintains data consistency across successful transaction' do
      workflow = Forms::AiFormGenerationWorkflow.new

      result = workflow.execute(
        user_id: user.id,
        content_input: prompt_content,
        input_type: 'prompt',
        metadata: metadata
      )

      expect(result[:success]).to be true

      # Verify all related records were created consistently
      form = Form.find(result[:form_id])
      questions = form.form_questions

      # Verify form-question relationships
      expect(questions.all? { |q| q.form_id == form.id }).to be true

      # Verify question positions are sequential
      positions = questions.pluck(:position).sort
      expect(positions).to eq((1..questions.count).to_a)

      # Verify AI configurations are consistent
      ai_enhanced_questions = questions.where(ai_enhanced: true)
      expect(ai_enhanced_questions.all? { |q| q.ai_config.present? }).to be true

      # Verify metadata consistency
      expect(form.metadata['ai_cost']).to eq(user.reload.ai_credits_used)
      expect(form.ai_enabled).to be true
      expect(form.ai_configuration['enabled']).to be true
    end
  end

  describe 'AI feature configuration and form optimization' do
    let(:lead_capture_analysis) do
      mock_analysis_response.tap do |response|
        parsed = JSON.parse(response)
        parsed['recommended_approach'] = 'lead_capture'
        parsed['complexity_level'] = 'complex'
        parsed['requires_branching_logic'] = true
        response.replace(parsed.to_json)
      end
    end

    let(:lead_capture_generation) do
      mock_generation_response.tap do |response|
        parsed = JSON.parse(response)
        parsed['form_meta']['category'] = 'lead_generation'
        parsed['form_settings']['one_question_per_page'] = true
        parsed['form_settings']['collect_email'] = true
        # Add email question if not present
        unless parsed['questions'].any? { |q| q['question_type'] == 'email' }
          parsed['questions'] << {
            'title' => 'Your business email',
            'question_type' => 'email',
            'required' => true,
            'question_config' => { 'validation' => 'email' },
            'position_rationale' => 'Email required for lead qualification'
          }
        end
        response.replace(parsed.to_json)
      end
    end

    before do
      allow_any_instance_of(SuperAgent::LlmInterface).to receive(:call).and_return(lead_capture_analysis, lead_capture_generation)
    end

    it 'configures AI features based on form approach' do
      workflow = Forms::AiFormGenerationWorkflow.new

      result = workflow.execute(
        user_id: user.id,
        content_input: "I need a lead qualification form for my B2B software company to identify potential customers and their needs.",
        input_type: 'prompt',
        metadata: metadata
      )

      expect(result[:success]).to be true

      form = Form.find(result[:form_id])

      # Verify lead capture specific AI features
      expect(form.ai_configuration['features']).to include('lead_scoring')
      expect(form.ai_configuration['features']).to include('intent_detection')
      expect(form.ai_configuration['features']).to include('dynamic_followup') # Due to branching logic

      # Verify complex form optimizations
      expect(form.form_settings['one_question_per_page']).to be true
      expect(form.form_settings['show_progress_bar']).to be true
      expect(form.form_settings['collect_email']).to be true

      # Verify email question is present and AI-enhanced
      email_question = form.form_questions.find { |q| q.question_type == 'email' }
      expect(email_question).to be_present
      expect(email_question.ai_enhanced).to be true
      expect(email_question.ai_config['validation_enhancement']).to be true
    end

    it 'optimizes form settings based on complexity level' do
      # Test with simple complexity
      simple_analysis = JSON.parse(mock_analysis_response)
      simple_analysis['complexity_level'] = 'simple'
      simple_analysis['suggested_question_count'] = 3

      simple_generation = JSON.parse(mock_generation_response)
      simple_generation['questions'] = simple_generation['questions'].first(3)
      simple_generation['form_settings']['one_question_per_page'] = false
      simple_generation['form_settings']['show_progress_bar'] = false

      allow_any_instance_of(SuperAgent::LlmInterface).to receive(:call).and_return(simple_analysis.to_json, simple_generation.to_json)

      workflow = Forms::AiFormGenerationWorkflow.new

      result = workflow.execute(
        user_id: user.id,
        content_input: "Simple contact form with name, email, message",
        input_type: 'prompt',
        metadata: metadata
      )

      expect(result[:success]).to be true

      form = Form.find(result[:form_id])

      # Verify simple form optimizations
      expect(form.form_settings['one_question_per_page']).to be false
      expect(form.form_settings['show_progress_bar']).to be false
      expect(form.form_questions.count).to eq(3)
    end

    it 'applies question-specific AI configurations correctly' do
      workflow = Forms::AiFormGenerationWorkflow.new

      result = workflow.execute(
        user_id: user.id,
        content_input: prompt_content,
        input_type: 'prompt',
        metadata: metadata
      )

      expect(result[:success]).to be true

      form = Form.find(result[:form_id])
      questions = form.form_questions

      # Verify text_long questions have sentiment analysis
      text_questions = questions.where(question_type: 'text_long')
      text_questions.each do |question|
        expect(question.ai_enhanced).to be true
        expect(question.ai_config['sentiment_analysis']).to be true
        expect(question.ai_config['keyword_extraction']).to be true
      end

      # Verify email questions have validation enhancement
      email_questions = questions.where(question_type: 'email')
      email_questions.each do |question|
        expect(question.ai_enhanced).to be true
        expect(question.ai_config['validation_enhancement']).to be true
        expect(question.ai_config['format_suggestions']).to be true
      end

      # Verify rating questions have appropriate AI config
      rating_questions = questions.where(question_type: 'rating')
      rating_questions.each do |question|
        expect(question.ai_enhanced).to be true
        expect(question.ai_config['sentiment_correlation']).to be true
      end

      # Verify non-AI-enhanced question types
      non_ai_questions = questions.where(question_type: ['date', 'number'])
      non_ai_questions.each do |question|
        expect(question.ai_enhanced).to be false
        expect(question.ai_config).to be_empty
      end
    end
  end

  describe 'Error handling and recovery scenarios' do
    it 'handles LLM analysis failures gracefully' do
      # Mock LLM failure for analysis
      allow_any_instance_of(SuperAgent::LlmInterface).to receive(:call).and_raise(StandardError, 'LLM service unavailable')

      workflow = Forms::AiFormGenerationWorkflow.new

      result = workflow.execute(
        user_id: user.id,
        content_input: prompt_content,
        input_type: 'prompt',
        metadata: metadata
      )

      expect(result[:success]).to be false
      expect(result[:error_type]).to eq('llm_error')
      expect(result[:message]).to include('AI analysis failed')

      # Verify no form was created and no credits deducted
      expect(Form.where(user: user).count).to eq(0)
      user.reload
      expect(user.ai_credits_used).to eq(0.0)
    end

    it 'handles LLM generation failures gracefully' do
      # Mock successful analysis but failed generation
      call_count = 0
      allow_any_instance_of(SuperAgent::LlmInterface).to receive(:call) do
        call_count += 1
        if call_count == 1
          mock_analysis_response
        else
          raise StandardError, 'LLM generation service unavailable'
        end
      end

      workflow = Forms::AiFormGenerationWorkflow.new

      result = workflow.execute(
        user_id: user.id,
        content_input: prompt_content,
        input_type: 'prompt',
        metadata: metadata
      )

      expect(result[:success]).to be false
      expect(result[:error_type]).to eq('llm_error')
      expect(result[:message]).to include('AI form generation failed')

      # Verify no form was created and no credits deducted
      expect(Form.where(user: user).count).to eq(0)
      user.reload
      expect(user.ai_credits_used).to eq(0.0)
    end

    it 'handles malformed LLM JSON responses with retries' do
      # Mock malformed JSON responses that eventually succeed
      call_count = 0
      allow_any_instance_of(SuperAgent::LlmInterface).to receive(:call) do
        call_count += 1
        case call_count
        when 1
          mock_analysis_response # Successful analysis
        when 2, 3
          'invalid json response' # Malformed responses
        when 4
          mock_generation_response # Eventually successful
        end
      end

      workflow = Forms::AiFormGenerationWorkflow.new

      result = workflow.execute(
        user_id: user.id,
        content_input: prompt_content,
        input_type: 'prompt',
        metadata: metadata
      )

      expect(result[:success]).to be true
      expect(result[:form_id]).to be_present

      # Verify form was created despite initial failures
      form = Form.find(result[:form_id])
      expect(form).to be_present

      # Verify retry cost was included
      expect(form.metadata['ai_cost']).to be > 0.1 # Should include retry costs
    end

    it 'handles validation failures with detailed error messages' do
      # Mock LLM response with invalid structure
      invalid_generation = {
        'form_meta' => {
          'title' => 'A' * 100, # Too long
          'category' => 'invalid_category'
        },
        'questions' => [
          {
            'title' => 'Test Question',
            'question_type' => 'invalid_type', # Invalid type
            'required' => 'not_boolean' # Invalid boolean
          }
        ],
        'form_settings' => 'not_a_hash' # Invalid structure
      }.to_json

      allow_any_instance_of(SuperAgent::LlmInterface).to receive(:call).and_return(mock_analysis_response, invalid_generation)

      workflow = Forms::AiFormGenerationWorkflow.new

      result = workflow.execute(
        user_id: user.id,
        content_input: prompt_content,
        input_type: 'prompt',
        metadata: metadata
      )

      expect(result[:success]).to be false
      expect(result[:error_type]).to eq('generation_validation_error')
      expect(result[:message]).to include('invalid structure')

      # Verify no form was created
      expect(Form.where(user: user).count).to eq(0)
    end
  end

  private

  def create_test_document(filename, content_type, content)
    tempfile = Tempfile.new([filename, File.extname(filename)])
    tempfile.write(content)
    tempfile.rewind

    ActionDispatch::Http::UploadedFile.new(
      tempfile: tempfile,
      filename: filename,
      type: content_type,
      head: "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\nContent-Type: #{content_type}\r\n"
    )
  end
end