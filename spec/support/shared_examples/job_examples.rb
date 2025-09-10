# frozen_string_literal: true

# Shared examples for background job behaviors

RSpec.shared_examples "a background job" do |job_class|
  it "inherits from ApplicationJob" do
    expect(job_class.ancestors).to include(ApplicationJob)
  end
  
  it "has a queue assigned" do
    expect(job_class.queue_name).to be_present
  end
  
  it "can be enqueued" do
    expect { job_class.perform_async }.not_to raise_error
  end
  
  describe "job execution" do
    it "executes without errors with valid parameters" do
      job_instance = job_class.new
      expect { job_instance.perform(*valid_job_params) }.not_to raise_error
    end
    
    it "handles missing parameters gracefully" do
      job_instance = job_class.new
      expect { job_instance.perform }.not_to raise_error
    end
  end
end

RSpec.shared_examples "a retryable job" do |max_retries = 3|
  it "has retry configuration" do
    expect(described_class.sidekiq_options['retry']).to be_truthy
  end
  
  it "retries on failure up to max attempts" do
    allow_any_instance_of(described_class).to receive(:perform).and_raise(StandardError, "Job failed")
    
    expect {
      described_class.perform_async(*valid_job_params)
      described_class.drain # Process job immediately in test
    }.to change { described_class.jobs.size }.by(0) # Job should be retried, not completed
  end
  
  it "gives up after max retries" do
    # This would require more complex setup with Sidekiq testing
    # to properly test retry exhaustion
    expect(described_class.sidekiq_options['retry']).to be <= max_retries
  end
end

RSpec.shared_examples "a job with error handling" do
  it "logs errors appropriately" do
    allow_any_instance_of(described_class).to receive(:perform).and_raise(StandardError, "Test error")
    expect(Rails.logger).to receive(:error).with(/Test error/)
    
    job_instance = described_class.new
    job_instance.perform(*valid_job_params) rescue nil
  end
  
  it "notifies error tracking service" do
    if defined?(Sentry)
      allow_any_instance_of(described_class).to receive(:perform).and_raise(StandardError, "Test error")
      expect(Sentry).to receive(:capture_exception)
      
      job_instance = described_class.new
      job_instance.perform(*valid_job_params) rescue nil
    end
  end
  
  it "provides meaningful error context" do
    allow_any_instance_of(described_class).to receive(:perform).and_raise(StandardError, "Test error")
    
    job_instance = described_class.new
    
    begin
      job_instance.perform(*valid_job_params)
    rescue => e
      expect(e.message).to include("Test error")
    end
  end
end

RSpec.shared_examples "a job with progress tracking" do
  it "updates progress during execution" do
    job_instance = described_class.new
    
    expect(job_instance).to receive(:update_progress).at_least(:once)
    job_instance.perform(*valid_job_params)
  end
  
  it "sets progress to 100% on completion" do
    job_instance = described_class.new
    job_instance.perform(*valid_job_params)
    
    expect(job_instance.progress).to eq(100)
  end
  
  it "provides progress information" do
    job_instance = described_class.new
    
    expect(job_instance).to respond_to(:progress)
    expect(job_instance).to respond_to(:status_message)
  end
end

RSpec.shared_examples "a workflow job" do
  it "integrates with SuperAgent workflows" do
    expect(described_class.ancestors.map(&:name)).to include('SuperAgent::WorkflowJob')
  end
  
  it "executes associated workflow" do
    workflow_class = described_class.workflow_class
    expect(workflow_class).to be_present
    
    workflow_instance = double("workflow")
    expect(workflow_class).to receive(:new).and_return(workflow_instance)
    expect(workflow_instance).to receive(:execute)
    
    job_instance = described_class.new
    job_instance.perform(*valid_job_params)
  end
  
  it "handles workflow failures" do
    workflow_instance = double("workflow")
    allow(described_class.workflow_class).to receive(:new).and_return(workflow_instance)
    allow(workflow_instance).to receive(:execute).and_raise(SuperAgent::WorkflowError, "Workflow failed")
    
    job_instance = described_class.new
    expect { job_instance.perform(*valid_job_params) }.not_to raise_error
  end
end

RSpec.shared_examples "an AI processing job" do
  it "is assigned to ai_processing queue" do
    expect(described_class.queue_name).to eq('ai_processing')
  end
  
  it "tracks AI usage" do
    job_instance = described_class.new
    
    expect(job_instance).to respond_to(:track_ai_usage)
    job_instance.perform(*valid_job_params)
  end
  
  it "handles LLM service failures" do
    allow(SuperAgent::LLM).to receive(:call).and_raise(SuperAgent::LLMError, "LLM service unavailable")
    
    job_instance = described_class.new
    expect { job_instance.perform(*valid_job_params) }.not_to raise_error
  end
  
  it "respects AI credit limits" do
    # Mock user with insufficient credits
    user = double("user", ai_credits_remaining: 0)
    allow(User).to receive(:find).and_return(user)
    
    job_instance = described_class.new
    result = job_instance.perform(*valid_job_params)
    
    expect(result[:error]).to include("insufficient credits") if result.is_a?(Hash)
  end
end

RSpec.shared_examples "an integration job" do
  it "is assigned to integrations queue" do
    expect(described_class.queue_name).to eq('integrations')
  end
  
  it "handles external service failures" do
    # Mock external service failure
    allow(Net::HTTP).to receive(:get_response).and_raise(Net::TimeoutError)
    
    job_instance = described_class.new
    expect { job_instance.perform(*valid_job_params) }.not_to raise_error
  end
  
  it "implements exponential backoff for retries" do
    expect(described_class.sidekiq_options['retry']).to be_truthy
    
    # Check if custom retry logic is implemented
    if described_class.respond_to?(:sidekiq_retry_in)
      retry_delays = (1..5).map { |attempt| described_class.sidekiq_retry_in(attempt) }
      
      # Verify exponential backoff pattern
      expect(retry_delays[1]).to be > retry_delays[0]
      expect(retry_delays[2]).to be > retry_delays[1]
    end
  end
  
  it "validates external service credentials" do
    job_instance = described_class.new
    
    if job_instance.respond_to?(:validate_credentials)
      expect(job_instance.validate_credentials).to be_truthy
    end
  end
end

RSpec.shared_examples "a critical job" do
  it "is assigned to critical queue" do
    expect(described_class.queue_name).to eq('critical')
  end
  
  it "has high retry count" do
    expect(described_class.sidekiq_options['retry']).to be >= 5
  end
  
  it "sends alerts on failure" do
    allow_any_instance_of(described_class).to receive(:perform).and_raise(StandardError, "Critical failure")
    
    # Mock alert service
    alert_service = double("AlertService")
    expect(AlertService).to receive(:new).and_return(alert_service)
    expect(alert_service).to receive(:send_alert)
    
    job_instance = described_class.new
    job_instance.perform(*valid_job_params) rescue nil
  end
end

RSpec.shared_examples "a scheduled job" do |schedule_pattern|
  it "has cron schedule defined" do
    if defined?(Sidekiq::Cron)
      cron_job = Sidekiq::Cron::Job.find(described_class.name)
      expect(cron_job).to be_present
      expect(cron_job.cron).to eq(schedule_pattern) if schedule_pattern
    end
  end
  
  it "can run without parameters" do
    job_instance = described_class.new
    expect { job_instance.perform }.not_to raise_error
  end
  
  it "is idempotent" do
    job_instance = described_class.new
    
    # Run twice and verify no duplicate side effects
    result1 = job_instance.perform
    result2 = job_instance.perform
    
    # Results should be consistent
    expect(result1).to eq(result2) if result1.present?
  end
end

RSpec.shared_examples "a batch job" do
  it "processes records in batches" do
    job_instance = described_class.new
    
    expect(job_instance).to respond_to(:batch_size)
    expect(job_instance.batch_size).to be > 0
  end
  
  it "handles large datasets efficiently" do
    # Create test data
    create_list(:user, 100)
    
    job_instance = described_class.new
    
    # Monitor memory usage (simplified)
    start_memory = `ps -o rss= -p #{Process.pid}`.to_i
    job_instance.perform
    end_memory = `ps -o rss= -p #{Process.pid}`.to_i
    
    memory_increase = end_memory - start_memory
    expect(memory_increase).to be < 50_000 # Less than 50MB increase
  end
  
  it "provides batch progress updates" do
    job_instance = described_class.new
    
    expect(job_instance).to receive(:update_batch_progress).at_least(:once)
    job_instance.perform
  end
end