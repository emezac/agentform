# frozen_string_literal: true

module WorkflowHelpers
  # Mock LLM response for SuperAgent workflows
  def mock_llm_response(response_data, model: 'gpt-4', status: 'success')
    response = {
      'status' => status,
      'model' => model,
      'response' => response_data,
      'usage' => {
        'prompt_tokens' => 100,
        'completion_tokens' => 50,
        'total_tokens' => 150
      },
      'created_at' => Time.current.iso8601
    }
    
    # Handle case where SuperAgent::LLM might not be loaded
    if defined?(SuperAgent::LLM)
      allow(SuperAgent::LLM).to receive(:call).and_return(response)
    else
      # Create a stub for testing when SuperAgent is not available
      llm_class = Class.new do
        def self.call(*args)
          response
        end
      end
      stub_const('SuperAgent::LLM', llm_class)
      allow(SuperAgent::LLM).to receive(:call).and_return(response)
    end
    
    response
  end

  # Mock LLM error response
  def mock_llm_error(error_message = 'Service unavailable', error_code = 'service_error')
    error_response = {
      'status' => 'error',
      'error' => {
        'code' => error_code,
        'message' => error_message
      }
    }
    
    # Handle case where SuperAgent classes might not be loaded
    if defined?(SuperAgent::ServiceError)
      error_class = SuperAgent::ServiceError
    else
      error_class = Class.new(StandardError)
      stub_const('SuperAgent::ServiceError', error_class)
    end
    
    if defined?(SuperAgent::LLM)
      allow(SuperAgent::LLM).to receive(:call).and_raise(error_class.new(error_message))
    else
      llm_class = Class.new do
        def self.call(*args)
          raise error_class.new(error_message)
        end
      end
      stub_const('SuperAgent::LLM', llm_class)
      allow(SuperAgent::LLM).to receive(:call).and_raise(error_class.new(error_message))
    end
    
    error_response
  end

  # Simulate workflow execution with mocked dependencies
  def simulate_workflow_execution(workflow_class, inputs = {}, mocks = {})
    # Apply any LLM mocks
    if mocks[:llm_responses]
      mocks[:llm_responses].each do |response|
        mock_llm_response(response)
      end
    end

    # Apply any service mocks
    if mocks[:services]
      mocks[:services].each do |service, response|
        allow(service).to receive(:call).and_return(response)
      end
    end

    # Execute workflow
    workflow = workflow_class.new(inputs)
    result = workflow.execute
    
    # Return both workflow instance and result for inspection
    { workflow: workflow, result: result }
  end

  # Expect specific workflow step to be executed
  def expect_workflow_step(workflow, step_name, times: 1)
    expect(workflow).to receive(:execute_step).with(step_name).exactly(times).times
  end

  # Expect workflow to complete successfully
  def expect_workflow_success(workflow_result)
    expect(workflow_result[:result]).to be_successful
    expect(workflow_result[:workflow].status).to eq('completed')
  end

  # Expect workflow to fail at specific step
  def expect_workflow_failure(workflow_result, failed_step = nil, error_type = nil)
    expect(workflow_result[:result]).to be_failed
    expect(workflow_result[:workflow].status).to eq('failed')
    
    if failed_step
      expect(workflow_result[:workflow].failed_step).to eq(failed_step)
    end
    
    if error_type
      expect(workflow_result[:workflow].error_type).to eq(error_type)
    end
  end

  # Mock streaming updates for workflows
  def mock_streaming_update(channel, data)
    allow(ActionCable.server).to receive(:broadcast).with(channel, data)
  end

  # Expect streaming update to be sent
  def expect_streaming_update(channel, data = nil)
    if data
      expect(ActionCable.server).to have_received(:broadcast).with(channel, data)
    else
      expect(ActionCable.server).to have_received(:broadcast).with(channel, anything)
    end
  end

  # Create workflow test data
  def create_workflow_test_data(type = :form_response)
    case type
    when :form_response
      form = create(:form, :published)
      create(:form_response, form: form, status: :in_progress)
    when :form_analysis
      form = create(:form, :published, :with_responses)
      form.form_responses.first
    when :dynamic_question
      form = create(:form, :published)
      question = create(:form_question, form: form, ai_enhanced: true)
      response = create(:form_response, form: form)
      create(:question_response, form_question: question, form_response: response)
    end
  end

  # Mock agent behavior
  def mock_agent_method(agent_class, method_name, return_value = true)
    allow_any_instance_of(agent_class).to receive(method_name).and_return(return_value)
  end

  # Expect agent method to be called
  def expect_agent_method_called(agent_class, method_name, times: 1)
    expect_any_instance_of(agent_class).to receive(method_name).exactly(times).times
  end

  # Mock background job execution
  def mock_background_job(job_class, method: :perform_async)
    allow(job_class).to receive(method).and_return(true)
  end

  # Expect background job to be enqueued
  def expect_job_enqueued(job_class, args = nil, times: 1)
    if args
      expect(job_class).to have_enqueued_sidekiq_job(*args).exactly(times).times
    else
      expect(job_class).to have_enqueued_sidekiq_job.exactly(times).times
    end
  end

  # Test workflow performance
  def benchmark_workflow(workflow_class, inputs = {}, iterations = 1)
    times = []
    
    iterations.times do
      start_time = Time.current
      workflow = workflow_class.new(inputs)
      workflow.execute
      end_time = Time.current
      
      times << (end_time - start_time)
    end
    
    {
      average: times.sum / times.length,
      min: times.min,
      max: times.max,
      total: times.sum
    }
  end

  # Mock AI analysis results
  def mock_ai_analysis_result(type = :response_analysis)
    case type
    when :response_analysis
      {
        'sentiment' => 'positive',
        'confidence' => 0.85,
        'key_themes' => ['satisfaction', 'quality', 'service'],
        'summary' => 'Customer expressed high satisfaction with the service quality.',
        'recommendations' => ['Follow up for testimonial', 'Offer loyalty program']
      }
    when :form_analysis
      {
        'completion_rate' => 0.78,
        'average_time' => 180,
        'drop_off_points' => [3, 7],
        'optimization_suggestions' => [
          'Simplify question 3',
          'Add progress indicator at question 7'
        ]
      }
    when :dynamic_question
      {
        'question_type' => 'text_short',
        'question_text' => 'What specific aspect of our service impressed you most?',
        'reasoning' => 'Follow-up based on positive sentiment to gather specific feedback',
        'priority' => 'high'
      }
    end
  end

  # Create workflow execution context
  def create_workflow_context(user: nil, form: nil, **additional_context)
    context = {
      user: user || create(:user),
      form: form || create(:form),
      timestamp: Time.current,
      request_id: SecureRandom.uuid
    }
    
    context.merge(additional_context)
  end

  # Verify workflow audit trail
  def expect_workflow_audit_trail(workflow, expected_steps)
    audit_trail = workflow.audit_trail
    
    expected_steps.each_with_index do |step_name, index|
      expect(audit_trail[index][:step]).to eq(step_name)
      expect(audit_trail[index][:status]).to be_in(['completed', 'skipped'])
      expect(audit_trail[index][:timestamp]).to be_present
    end
  end

  # Mock external service integrations
  def mock_integration_service(service_name, response = { success: true })
    service_class = "Forms::Integrations::#{service_name.to_s.camelize}Service".constantize
    allow(service_class).to receive(:call).and_return(response)
  rescue NameError
    # Service class doesn't exist, create a mock
    stub_const("Forms::Integrations::#{service_name.to_s.camelize}Service", Class.new)
    allow("Forms::Integrations::#{service_name.to_s.camelize}Service".constantize)
      .to receive(:call).and_return(response)
  end

  # Test workflow retry behavior
  def test_workflow_retry(workflow_class, inputs, failure_step, max_retries = 3)
    retry_count = 0
    
    allow_any_instance_of(workflow_class).to receive(:execute_step) do |instance, step|
      if step == failure_step && retry_count < max_retries
        retry_count += 1
        raise StandardError, "Simulated failure"
      else
        # Normal execution
        instance.send("original_execute_step", step)
      end
    end
    
    workflow = workflow_class.new(inputs)
    result = workflow.execute
    
    { result: result, retry_count: retry_count }
  end
end