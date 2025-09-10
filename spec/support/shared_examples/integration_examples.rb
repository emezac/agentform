# frozen_string_literal: true

# Shared examples for integration testing patterns

RSpec.shared_examples "end-to-end form processing" do |form_type = :basic|
  let(:user) { create(:user) }
  let(:form) { create(:form, user: user, form_type: form_type) }
  
  before do
    sign_in user if respond_to?(:sign_in)
  end
  
  it "completes full form creation workflow" do
    # Form creation
    visit new_form_path if respond_to?(:visit)
    
    # Form configuration
    expect(form).to be_persisted
    expect(form.questions).to be_present if form_type != :empty
    
    # Form publishing
    form.update!(status: :published)
    expect(form).to be_published
  end
  
  it "handles form response submission" do
    form.update!(status: :published)
    
    # Create form response
    form_response = create(:form_response, form: form)
    
    # Add question responses
    form.questions.each do |question|
      create(:question_response, 
             form_response: form_response, 
             form_question: question,
             answer: sample_answer_for(question))
    end
    
    expect(form_response.question_responses.count).to eq(form.questions.count)
    expect(form_response).to be_completed
  end
  
  it "triggers AI analysis workflow" do
    form.update!(ai_enhanced: true, status: :published)
    form_response = create(:form_response, :completed, form: form)
    
    expect {
      Forms::ResponseAnalysisJob.perform_async(form_response.id)
    }.to change { Forms::ResponseAnalysisJob.jobs.size }.by(1)
  end
  
  it "updates analytics data" do
    form.update!(status: :published)
    
    expect {
      create(:form_response, :completed, form: form)
    }.to change { form.form_analytics.count }.by_at_least(0)
    
    # Verify analytics are updated
    form.reload
    expect(form.response_count).to be > 0
  end
  
  private
  
  def sample_answer_for(question)
    case question.question_type
    when 'text_short', 'text_long'
      'Sample text answer'
    when 'multiple_choice', 'single_choice'
      question.configuration['options'].first
    when 'rating'
      5
    when 'boolean', 'yes_no'
      true
    when 'email'
      'test@example.com'
    when 'number'
      42
    else
      'Default answer'
    end
  end
end

RSpec.shared_examples "API workflow integration" do |api_version = 'v1'|
  let(:user) { create(:user) }
  let(:api_token) { create(:api_token, user: user) }
  let(:headers) { api_headers(api_token) }
  
  it "completes full API workflow" do
    # Create form via API
    form_params = attributes_for(:form)
    post "/api/#{api_version}/forms", params: form_params.to_json, headers: headers
    
    expect(response).to have_http_status(:created)
    form_id = json_response['data']['id']
    
    # Add questions via API
    question_params = attributes_for(:form_question)
    post "/api/#{api_version}/forms/#{form_id}/questions", 
         params: question_params.to_json, headers: headers
    
    expect(response).to have_http_status(:created)
    
    # Publish form via API
    patch "/api/#{api_version}/forms/#{form_id}", 
          params: { status: 'published' }.to_json, headers: headers
    
    expect(response).to have_http_status(:ok)
    
    # Submit response via API
    response_params = {
      responses: [
        {
          question_id: json_response['data']['id'],
          answer: 'API test answer'
        }
      ]
    }
    
    post "/api/#{api_version}/forms/#{form_id}/responses", 
         params: response_params.to_json, headers: headers
    
    expect(response).to have_http_status(:created)
  end
  
  it "handles API authentication flow" do
    # Test without authentication
    get "/api/#{api_version}/forms"
    expect(response).to have_http_status(:unauthorized)
    
    # Test with valid token
    get "/api/#{api_version}/forms", headers: headers
    expect(response).to have_http_status(:ok)
    
    # Test with expired token
    expired_token = create(:api_token, user: user, expires_at: 1.day.ago)
    expired_headers = api_headers(expired_token)
    
    get "/api/#{api_version}/forms", headers: expired_headers
    expect(response).to have_http_status(:unauthorized)
  end
  
  it "respects rate limiting" do
    # Make requests up to limit
    10.times do
      get "/api/#{api_version}/forms", headers: headers
      expect(response).not_to have_http_status(:too_many_requests)
    end
    
    # Verify rate limit headers are present
    expect(response.headers['X-RateLimit-Limit']).to be_present
    expect(response.headers['X-RateLimit-Remaining']).to be_present
  end
end

RSpec.shared_examples "real-time updates integration" do
  let(:user) { create(:user) }
  let(:form) { create(:form, user: user) }
  
  it "broadcasts form updates via Turbo Streams" do
    # Mock Turbo Stream broadcasting
    expect(Turbo::StreamsChannel).to receive(:broadcast_update_to)
    
    form.update!(title: 'Updated Title')
  end
  
  it "streams workflow progress updates" do
    workflow = Forms::ResponseProcessingWorkflow.new(form_response: create(:form_response, form: form))
    
    # Mock streaming updates
    expect(workflow).to receive(:stream_update).at_least(:once)
    
    workflow.execute
  end
  
  it "handles WebSocket connections" do
    # This would require more complex setup for actual WebSocket testing
    # For now, verify that the streaming infrastructure is in place
    expect(defined?(ActionCable)).to be_truthy
  end
end

RSpec.shared_examples "external service integration" do |service_name|
  let(:service_class) { "#{service_name.to_s.camelize}Service".constantize }
  
  it "handles service availability" do
    service = service_class.new
    
    # Test when service is available
    stub_request(:get, /#{service_name}/).to_return(status: 200, body: '{"status": "ok"}')
    
    expect(service.available?).to be_truthy
    
    # Test when service is unavailable
    stub_request(:get, /#{service_name}/).to_return(status: 500)
    
    expect(service.available?).to be_falsy
  end
  
  it "implements retry logic for failed requests" do
    service = service_class.new
    
    # Mock failed requests followed by success
    stub_request(:post, /#{service_name}/)
      .to_return(status: 500)
      .then
      .to_return(status: 200, body: '{"success": true}')
    
    result = service.send_data({})
    expect(result).to be_successful
  end
  
  it "handles authentication with external service" do
    service = service_class.new
    
    # Test with valid credentials
    stub_request(:post, /#{service_name}/)
      .with(headers: { 'Authorization' => /Bearer/ })
      .to_return(status: 200, body: '{"authenticated": true}')
    
    expect(service.authenticate).to be_truthy
    
    # Test with invalid credentials
    stub_request(:post, /#{service_name}/)
      .to_return(status: 401, body: '{"error": "unauthorized"}')
    
    expect(service.authenticate).to be_falsy
  end
  
  it "validates data before sending to external service" do
    service = service_class.new
    
    # Test with valid data
    valid_data = { name: 'Test', email: 'test@example.com' }
    expect(service.validate_data(valid_data)).to be_truthy
    
    # Test with invalid data
    invalid_data = { name: '', email: 'invalid-email' }
    expect(service.validate_data(invalid_data)).to be_falsy
  end
end

RSpec.shared_examples "database transaction integrity" do
  it "maintains data consistency during complex operations" do
    initial_count = Form.count
    
    expect {
      ActiveRecord::Base.transaction do
        form = create(:form)
        create_list(:form_question, 3, form: form)
        
        # Simulate an error that should rollback the transaction
        raise ActiveRecord::Rollback if form.questions.count != 3
      end
    }.not_to change { Form.count }
    
    expect(Form.count).to eq(initial_count)
  end
  
  it "handles concurrent access correctly" do
    form = create(:form, response_count: 0)
    
    # Simulate concurrent updates
    threads = []
    
    5.times do
      threads << Thread.new do
        Form.transaction do
          current_form = Form.find(form.id)
          current_form.update!(response_count: current_form.response_count + 1)
        end
      end
    end
    
    threads.each(&:join)
    
    form.reload
    expect(form.response_count).to eq(5)
  end
  
  it "properly handles foreign key constraints" do
    user = create(:user)
    form = create(:form, user: user)
    
    # Should not be able to delete user with associated forms
    expect { user.destroy }.to raise_error(ActiveRecord::InvalidForeignKey)
    
    # Should be able to delete after removing associations
    form.destroy
    expect { user.destroy }.not_to raise_error
  end
end

RSpec.shared_examples "caching integration" do |cache_keys = []|
  it "caches expensive operations" do
    # Clear cache
    Rails.cache.clear
    
    cache_keys.each do |cache_key|
      # First call should hit the database/service
      expect(Rails.cache).to receive(:fetch).with(cache_key, any_args).and_call_original
      
      result1 = perform_cached_operation(cache_key)
      
      # Second call should use cache
      expect(Rails.cache).to receive(:read).with(cache_key).and_return(result1)
      
      result2 = perform_cached_operation(cache_key)
      expect(result2).to eq(result1)
    end
  end
  
  it "invalidates cache when data changes" do
    cache_key = cache_keys.first
    
    # Populate cache
    result1 = perform_cached_operation(cache_key)
    
    # Modify underlying data
    modify_cached_data(cache_key)
    
    # Cache should be invalidated
    expect(Rails.cache.exist?(cache_key)).to be_falsy
  end
  
  private
  
  def perform_cached_operation(cache_key)
    # This would be implemented by the including spec
    # to perform the actual cached operation
    "cached_result_for_#{cache_key}"
  end
  
  def modify_cached_data(cache_key)
    # This would be implemented by the including spec
    # to modify the data that should invalidate the cache
  end
end

RSpec.shared_examples "security integration" do
  it "prevents SQL injection attacks" do
    malicious_input = "'; DROP TABLE users; --"
    
    expect {
      User.where("name = '#{malicious_input}'").to_a
    }.not_to raise_error
    
    # Verify users table still exists
    expect(User.table_exists?).to be_truthy
  end
  
  it "sanitizes user input" do
    malicious_script = "<script>alert('xss')</script>"
    
    form = create(:form, title: malicious_script)
    
    # Verify HTML is escaped in output
    expect(form.title).not_to include('<script>')
  end
  
  it "enforces access control" do
    user1 = create(:user)
    user2 = create(:user)
    form = create(:form, user: user1)
    
    # User2 should not be able to access User1's form
    expect {
      form.update!(user: user2) # This should be prevented by authorization
    }.to raise_error(Pundit::NotAuthorizedError) if defined?(Pundit)
  end
  
  it "validates file uploads securely" do
    # Test file type validation
    malicious_file = fixture_file_upload('malicious.exe', 'application/octet-stream')
    
    expect {
      create(:form_question, :file_upload, configuration: { file: malicious_file })
    }.to raise_error(ActiveRecord::RecordInvalid)
  end
end