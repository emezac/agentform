# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Form Generation System', type: :system do
  let(:user) { create(:user, ai_credits_used: 0.0, monthly_ai_limit: 10.0) }
  let(:prompt_content) { "I need a customer feedback form for my restaurant to collect reviews and suggestions from diners about food quality, service, and ambiance." }

  before do
    # Sign in user for authenticated tests
    sign_in user
    
    # Mock successful LLM responses for consistent system testing
    mock_analysis_response = {
      'form_purpose' => 'Collect customer feedback for restaurant improvement',
      'target_audience' => 'Restaurant customers who have dined recently',
      'recommended_approach' => 'feedback',
      'complexity_level' => 'moderate',
      'estimated_completion_time' => 5,
      'suggested_question_count' => 4,
      'key_topics' => ['food quality', 'service', 'ambiance'],
      'requires_branching_logic' => false
    }.to_json

    mock_generation_response = {
      'form_meta' => {
        'title' => 'Restaurant Feedback Form',
        'description' => 'Help us improve your dining experience',
        'category' => 'customer_feedback',
        'instructions' => 'Please share your honest feedback'
      },
      'questions' => [
        {
          'title' => 'How would you rate your overall experience?',
          'description' => 'Please rate your overall satisfaction',
          'question_type' => 'rating',
          'required' => true,
          'question_config' => { 'min' => 1, 'max' => 5 },
          'position_rationale' => 'Opening with easy rating question'
        },
        {
          'title' => 'How was the food quality?',
          'description' => 'Rate the taste and presentation',
          'question_type' => 'rating',
          'required' => true,
          'question_config' => { 'min' => 1, 'max' => 5 },
          'position_rationale' => 'Core restaurant metric'
        },
        {
          'title' => 'Any additional comments?',
          'description' => 'Share your detailed feedback',
          'question_type' => 'text_long',
          'required' => false,
          'question_config' => { 'max_length' => 1000 },
          'position_rationale' => 'Open feedback after ratings'
        },
        {
          'title' => 'Your email for follow-up',
          'description' => 'Optional contact information',
          'question_type' => 'email',
          'required' => false,
          'question_config' => { 'validation' => 'email' },
          'position_rationale' => 'Contact info at end'
        }
      ],
      'form_settings' => {
        'one_question_per_page' => false,
        'show_progress_bar' => true,
        'allow_multiple_submissions' => false,
        'thank_you_message' => 'Thank you for your feedback!'
      }
    }.to_json

    allow_any_instance_of(SuperAgent::LlmInterface).to receive(:call).and_return(mock_analysis_response, mock_generation_response)
  end

  describe 'Complete user journey from input to form creation' do
    it 'allows user to create form from prompt input successfully', js: true do
      # Navigate to AI form generation page
      visit new_from_ai_forms_path

      # Verify page loads with correct elements
      expect(page).to have_content('Create Form with AI')
      expect(page).to have_selector('[data-controller*="tabs"]')
      expect(page).to have_selector('[data-controller*="ai-form-generator"]')
      expect(page).to have_selector('[data-controller*="form-preview"]')

      # Verify AI credits display
      expect(page).to have_content('AI Credits Remaining')
      expect(page).to have_content('10.0') # User's remaining credits

      # Verify prompt tab is active by default
      expect(page).to have_selector('.tab-button.active', text: 'Describe Your Form')

      # Enter prompt content
      fill_in 'prompt', with: prompt_content

      # Verify real-time word count feedback
      expect(page).to have_selector('[data-form-preview-target="wordCount"]')
      word_count_element = find('[data-form-preview-target="wordCount"]')
      expect(word_count_element.text.to_i).to be > 20

      # Verify cost estimation updates
      expect(page).to have_content('Estimated Cost')
      cost_element = find('[data-form-preview-target="estimatedCost"]', wait: 2)
      expect(cost_element.text).to match(/\$0\.\d+/)

      # Submit the form
      click_button 'Generate Form with AI'

      # Verify loading state
      expect(page).to have_selector('[data-ai-form-generator-target="submitButton"][disabled]', wait: 2)
      expect(page).to have_content('Generating your form...')

      # Wait for form generation to complete and redirect
      expect(page).to have_current_path(edit_form_path(Form.last), wait: 10)

      # Verify success message
      expect(page).to have_content('Form generated successfully!')

      # Verify form was created with correct details
      form = Form.last
      expect(form.name).to eq('Restaurant Feedback Form')
      expect(form.user).to eq(user)
      expect(form.ai_enabled).to be true

      # Verify questions were created
      expect(form.form_questions.count).to eq(4)

      # Verify form builder shows generated questions
      expect(page).to have_content('Restaurant Feedback Form')
      expect(page).to have_content('How would you rate your overall experience?')
      expect(page).to have_content('How was the food quality?')
      expect(page).to have_content('Any additional comments?')
      expect(page).to have_content('Your email for follow-up')

      # Verify AI enhancement indicators
      expect(page).to have_selector('.ai-enhanced', count: 2) # text_long and email questions
    end

    it 'shows validation errors for insufficient content', js: true do
      visit new_from_ai_forms_path

      # Enter content that is too short
      fill_in 'prompt', with: 'Too short'

      # Verify word count warning
      word_count_element = find('[data-form-preview-target="wordCount"]')
      expect(word_count_element.text.to_i).to be < 10

      # Submit the form
      click_button 'Generate Form with AI'

      # Verify error message appears
      expect(page).to have_content('Content too short', wait: 5)
      expect(page).to have_content('minimum 10 words')

      # Verify user stays on the same page
      expect(page).to have_current_path(new_from_ai_forms_path)

      # Verify form input is preserved
      expect(find_field('prompt').value).to eq('Too short')
    end

    it 'shows error for insufficient AI credits', js: true do
      # Update user to have insufficient credits
      user.update!(ai_credits_used: 9.95, monthly_ai_limit: 10.0)

      visit new_from_ai_forms_path

      # Verify credits warning is shown
      expect(page).to have_content('0.05') # Remaining credits

      fill_in 'prompt', with: prompt_content
      click_button 'Generate Form with AI'

      # Verify insufficient credits error
      expect(page).to have_content('Monthly AI usage limit exceeded', wait: 5)
      expect(page).to have_content('upgrade your plan')

      # Verify no form was created
      expect(Form.where(user: user).count).to eq(0)
    end
  end

  describe 'Stimulus controller interactions and state management' do
    it 'manages tab switching between prompt and document input', js: true do
      visit new_from_ai_forms_path

      # Verify prompt tab is active initially
      expect(page).to have_selector('.tab-button.active', text: 'Describe Your Form')
      expect(page).to have_selector('#prompt-tab.active')
      expect(page).to have_selector('#document-tab', visible: false)

      # Click document tab
      click_button 'Upload Document'

      # Verify tab switch
      expect(page).to have_selector('.tab-button.active', text: 'Upload Document')
      expect(page).to have_selector('#document-tab.active')
      expect(page).to have_selector('#prompt-tab', visible: false)

      # Click back to prompt tab
      click_button 'Describe Your Form'

      # Verify tab switch back
      expect(page).to have_selector('.tab-button.active', text: 'Describe Your Form')
      expect(page).to have_selector('#prompt-tab.active')
      expect(page).to have_selector('#document-tab', visible: false)
    end

    it 'provides real-time word count and cost estimation feedback', js: true do
      visit new_from_ai_forms_path

      prompt_field = find_field('prompt')
      word_count_target = find('[data-form-preview-target="wordCount"]')
      cost_target = find('[data-form-preview-target="estimatedCost"]')

      # Start with empty content
      expect(word_count_target.text).to eq('0')

      # Type content and verify real-time updates
      prompt_field.fill_in with: 'I need a simple contact form'
      
      # Wait for debounced update
      sleep 0.5
      
      expect(word_count_target.text.to_i).to eq(6)
      expect(cost_target.text).to match(/\$0\.\d+/)

      # Add more content
      prompt_field.fill_in with: prompt_content
      
      # Wait for update
      sleep 0.5
      
      expect(word_count_target.text.to_i).to be > 20
      
      # Verify cost increases with content length
      new_cost = cost_target.text.match(/\$(\d+\.\d+)/)[1].to_f
      expect(new_cost).to be > 0.05
    end

    it 'manages form submission state and loading indicators', js: true do
      visit new_from_ai_forms_path

      fill_in 'prompt', with: prompt_content

      submit_button = find('[data-ai-form-generator-target="submitButton"]')
      
      # Verify initial state
      expect(submit_button).not_to be_disabled
      expect(submit_button.text).to eq('Generate Form with AI')

      # Click submit and verify loading state
      submit_button.click

      # Verify button becomes disabled and shows loading text
      expect(submit_button).to be_disabled
      expect(page).to have_content('Generating your form...')

      # Verify loading indicator appears
      expect(page).to have_selector('.loading-indicator', wait: 2)
    end

    it 'handles form preview functionality', js: true do
      visit new_from_ai_forms_path

      # Enter content
      fill_in 'prompt', with: prompt_content

      # Verify preview updates
      preview_section = find('[data-controller*="form-preview"]')
      expect(preview_section).to be_present

      # Verify word count updates in real-time
      word_count = find('[data-form-preview-target="wordCount"]')
      expect(word_count.text.to_i).to be > 0

      # Verify estimated cost updates
      cost_estimate = find('[data-form-preview-target="estimatedCost"]')
      expect(cost_estimate.text).to match(/\$\d+\.\d+/)
    end
  end

  describe 'File upload functionality with various formats' do
    let(:text_file_content) { "Restaurant Feedback Requirements\n\nWe need to collect customer feedback about dining experience including food quality, service satisfaction, and ambiance rating." }

    before do
      # Mock successful document processing
      allow_any_instance_of(Ai::DocumentProcessor).to receive(:process).and_return({
        success: true,
        content: text_file_content,
        source_type: 'text_document',
        metadata: {
          file_name: 'requirements.txt',
          word_count: 22,
          content_type: 'text/plain'
        }
      })
    end

    it 'handles text file upload successfully', js: true do
      visit new_from_ai_forms_path

      # Switch to document tab
      click_button 'Upload Document'

      # Verify document upload interface
      expect(page).to have_selector('[data-controller*="file-upload"]')
      expect(page).to have_content('Drag and drop your document here')
      expect(page).to have_content('Supported formats: PDF, Markdown, Text')

      # Create and attach a test file
      file_path = create_temp_file('requirements.txt', text_file_content)
      
      # Upload file
      attach_file 'document', file_path, make_visible: true

      # Verify file info display
      expect(page).to have_selector('[data-file-upload-target="fileName"]', wait: 2)
      expect(page).to have_selector('[data-file-upload-target="fileSize"]')
      
      file_name_element = find('[data-file-upload-target="fileName"]')
      expect(file_name_element.text).to include('requirements.txt')

      # Submit form
      click_button 'Generate Form with AI'

      # Verify successful processing
      expect(page).to have_current_path(edit_form_path(Form.last), wait: 10)
      expect(page).to have_content('Form generated successfully!')

      # Clean up
      File.delete(file_path) if File.exist?(file_path)
    end

    it 'shows drag and drop visual feedback', js: true do
      visit new_from_ai_forms_path
      click_button 'Upload Document'

      drop_zone = find('[data-controller*="file-upload"]')
      
      # Verify initial state
      expect(drop_zone).not_to have_css('.drag-over')

      # Simulate drag over (would need more complex setup for full drag/drop testing)
      # For now, verify the drop zone elements are present
      expect(page).to have_selector('.drop-zone')
      expect(page).to have_content('Drag and drop your document here')
      expect(page).to have_selector('input[type="file"]', visible: false)
    end

    it 'validates file types and shows appropriate errors', js: true do
      visit new_from_ai_forms_path
      click_button 'Upload Document'

      # Mock document processing failure for unsupported file type
      allow_any_instance_of(Ai::DocumentProcessor).to receive(:process).and_return({
        success: false,
        errors: ['Unsupported file type. Supported types: PDF, Markdown, Plain text']
      })

      # Create an unsupported file type
      file_path = create_temp_file('image.jpg', 'fake image content')
      
      attach_file 'document', file_path, make_visible: true
      click_button 'Generate Form with AI'

      # Verify error message
      expect(page).to have_content('Unsupported file type', wait: 5)
      expect(page).to have_content('Supported types: PDF, Markdown, Plain text')

      # Verify user stays on form page
      expect(page).to have_current_path(generate_from_ai_forms_path)

      File.delete(file_path) if File.exist?(file_path)
    end

    it 'handles large file size validation', js: true do
      visit new_from_ai_forms_path
      click_button 'Upload Document'

      # Mock document processing failure for large file
      allow_any_instance_of(Ai::DocumentProcessor).to receive(:process).and_return({
        success: false,
        errors: ['File size must be less than 10 MB']
      })

      # Create a test file (simulating large file error)
      file_path = create_temp_file('large_file.txt', 'content')
      
      attach_file 'document', file_path, make_visible: true
      click_button 'Generate Form with AI'

      # Verify error message
      expect(page).to have_content('File size must be less than 10 MB', wait: 5)

      File.delete(file_path) if File.exist?(file_path)
    end
  end

  describe 'Error handling and recovery scenarios' do
    it 'handles LLM service failures gracefully', js: true do
      # Mock LLM service failure
      allow_any_instance_of(SuperAgent::LlmInterface).to receive(:call).and_raise(StandardError, 'Service unavailable')

      visit new_from_ai_forms_path
      fill_in 'prompt', with: prompt_content
      click_button 'Generate Form with AI'

      # Verify error message is displayed
      expect(page).to have_content('AI analysis failed', wait: 10)
      expect(page).to have_content('Please try again')

      # Verify user stays on form page
      expect(page).to have_current_path(generate_from_ai_forms_path)

      # Verify form input is preserved
      expect(find_field('prompt').value).to eq(prompt_content)

      # Verify submit button is re-enabled
      submit_button = find('[data-ai-form-generator-target="submitButton"]')
      expect(submit_button).not_to be_disabled
    end

    it 'handles network timeouts with retry options', js: true do
      # Mock timeout error
      allow_any_instance_of(SuperAgent::LlmInterface).to receive(:call).and_raise(Net::TimeoutError, 'Request timeout')

      visit new_from_ai_forms_path
      fill_in 'prompt', with: prompt_content
      click_button 'Generate Form with AI'

      # Verify timeout error message
      expect(page).to have_content('Request timed out', wait: 10)
      expect(page).to have_content('Please try again')

      # Verify retry functionality is available
      expect(page).to have_button('Generate Form with AI')
    end

    it 'shows validation errors with specific guidance', js: true do
      visit new_from_ai_forms_path

      # Test empty prompt
      click_button 'Generate Form with AI'

      expect(page).to have_content('Please provide content', wait: 5)

      # Test content too long
      long_content = 'word ' * 5001
      fill_in 'prompt', with: long_content.strip
      click_button 'Generate Form with AI'

      expect(page).to have_content('Content too long', wait: 5)
      expect(page).to have_content('Maximum 5000 words allowed')
    end

    it 'preserves user input during error recovery', js: true do
      # Mock service failure
      allow_any_instance_of(SuperAgent::LlmInterface).to receive(:call).and_raise(StandardError, 'Service error')

      visit new_from_ai_forms_path
      fill_in 'prompt', with: prompt_content
      click_button 'Generate Form with AI'

      # Wait for error
      expect(page).to have_content('failed', wait: 10)

      # Verify input is preserved
      expect(find_field('prompt').value).to eq(prompt_content)

      # Verify user can retry with same content
      # Fix the mock to succeed on retry
      allow_any_instance_of(SuperAgent::LlmInterface).to receive(:call).and_return(
        {
          'form_purpose' => 'Test form',
          'target_audience' => 'Test audience',
          'recommended_approach' => 'feedback',
          'complexity_level' => 'simple',
          'estimated_completion_time' => 3,
          'suggested_question_count' => 2,
          'key_topics' => ['test'],
          'requires_branching_logic' => false
        }.to_json,
        {
          'form_meta' => { 'title' => 'Test Form', 'description' => 'Test', 'category' => 'other' },
          'questions' => [
            {
              'title' => 'Test Question',
              'question_type' => 'text_short',
              'required' => true,
              'question_config' => {},
              'position_rationale' => 'Test rationale'
            }
          ],
          'form_settings' => {
            'one_question_per_page' => false,
            'show_progress_bar' => false,
            'allow_multiple_submissions' => false,
            'thank_you_message' => 'Thanks!'
          }
        }.to_json
      )

      click_button 'Generate Form with AI'

      # Verify successful retry
      expect(page).to have_current_path(edit_form_path(Form.last), wait: 10)
    end
  end

  describe 'Accessibility and mobile responsiveness' do
    it 'provides proper ARIA labels and keyboard navigation', js: true do
      visit new_from_ai_forms_path

      # Verify ARIA labels
      expect(page).to have_selector('[aria-label]', minimum: 3)
      expect(page).to have_selector('[role="tablist"]')
      expect(page).to have_selector('[role="tab"]', count: 2)
      expect(page).to have_selector('[role="tabpanel"]', count: 2)

      # Verify form labels
      expect(page).to have_selector('label[for="prompt"]')
      expect(page).to have_selector('label[for="document"]')

      # Test keyboard navigation
      prompt_tab = find('[role="tab"]', text: 'Describe Your Form')
      document_tab = find('[role="tab"]', text: 'Upload Document')

      # Tab should be focusable
      prompt_tab.send_keys(:tab)
      expect(document_tab).to match_css(':focus')
    end

    it 'works properly on mobile viewport', js: true do
      # Set mobile viewport
      page.driver.browser.manage.window.resize_to(375, 667)

      visit new_from_ai_forms_path

      # Verify mobile-optimized layout
      expect(page).to have_selector('.mobile-optimized', wait: 2)
      
      # Verify tabs are still functional on mobile
      expect(page).to have_selector('.tab-button', count: 2)
      
      # Verify form elements are touch-friendly
      prompt_field = find_field('prompt')
      expect(prompt_field[:class]).to include('touch-friendly')

      # Test mobile form submission
      fill_in 'prompt', with: 'Mobile test form for restaurant feedback'
      click_button 'Generate Form with AI'

      # Verify mobile loading state
      expect(page).to have_selector('.mobile-loading', wait: 2)
    end
  end

  private

  def create_temp_file(filename, content)
    file_path = Rails.root.join('tmp', filename)
    File.write(file_path, content)
    file_path.to_s
  end
end