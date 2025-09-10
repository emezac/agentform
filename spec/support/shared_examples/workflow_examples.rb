# frozen_string_literal: true

# Shared examples for SuperAgent workflow and agent behaviors

RSpec.shared_examples "a SuperAgent workflow" do |workflow_class|
  let(:workflow_instance) { workflow_class.new(workflow_inputs) }
  
  it "inherits from ApplicationWorkflow" do
    expect(workflow_class.ancestors).to include(ApplicationWorkflow)
  end
  
  it "responds to execute method" do
    expect(workflow_instance).to respond_to(:execute)
  end
  
  it "has defined steps" do
    expect(workflow_class.steps).to be_present
    expect(workflow_class.steps).to be_an(Array)
  end
  
  it "tracks execution state" do
    expect(workflow_instance).to respond_to(:status)
    expect(workflow_instance).to respond_to(:current_step)
    expect(workflow_instance).to respond_to(:completed_steps)
  end
  
  describe "#execute" do
    context "with valid inputs" do
      it "executes successfully" do
        allow_any_instance_of(workflow_class).to receive(:execute_step).and_return(true)
        
        result = workflow_instance.execute
        expect(result).to be_successful
      end
      
      it "executes steps in order" do
        step_execution_order = []
        
        allow_any_instance_of(workflow_class).to receive(:execute_step) do |_, step_name|
          step_execution_order << step_name
          true
        end
        
        workflow_instance.execute
        
        expect(step_execution_order).to eq(workflow_class.steps)
      end
    end
    
    context "with step failure" do
      let(:failing_step) { workflow_class.steps.first }
      
      before do
        allow_any_instance_of(workflow_class).to receive(:execute_step) do |_, step_name|
          step_name == failing_step ? false : true
        end
      end
      
      it "stops execution on first failure" do
        result = workflow_instance.execute
        expect(result).to be_failed
        expect(workflow_instance.failed_step).to eq(failing_step)
      end
      
      it "does not execute subsequent steps after failure" do
        executed_steps = []
        
        allow_any_instance_of(workflow_class).to receive(:execute_step) do |_, step_name|
          executed_steps << step_name
          step_name == failing_step ? false : true
        end
        
        workflow_instance.execute
        
        expect(executed_steps).to eq([failing_step])
      end
    end
  end
  
  describe "error handling" do
    it "handles exceptions gracefully" do
      allow_any_instance_of(workflow_class).to receive(:execute_step).and_raise(StandardError, "Test error")
      
      expect { workflow_instance.execute }.not_to raise_error
      
      result = workflow_instance.execute
      expect(result).to be_failed
      expect(result.error_message).to include("Test error")
    end
    
    it "supports retry logic" do
      call_count = 0
      allow_any_instance_of(workflow_class).to receive(:execute_step) do
        call_count += 1
        call_count < 3 ? false : true
      end
      
      # Assuming workflow has retry configuration
      if workflow_class.respond_to?(:retry_attempts)
        result = workflow_instance.execute
        expect(call_count).to be >= 2
      end
    end
  end
  
  describe "timeout handling" do
    it "respects timeout configuration" do
      # Mock a long-running step
      allow_any_instance_of(workflow_class).to receive(:execute_step) do
        sleep 0.1
        true
      end
      
      # Set a very short timeout for testing
      allow(workflow_instance).to receive(:timeout).and_return(0.05)
      
      result = workflow_instance.execute
      expect(result).to be_failed
      expect(result.error_type).to eq(:timeout)
    end
  end
end

RSpec.shared_examples "a workflow with LLM tasks" do |llm_steps = []|
  let(:mock_llm_response) { { "analysis" => "test analysis", "confidence" => 0.85 } }
  
  before do
    # Mock LLM responses for all LLM steps
    llm_steps.each do |step_name|
      allow_any_instance_of(described_class).to receive(:execute_llm_task)
        .with(step_name, anything)
        .and_return(mock_llm_response)
    end
  end
  
  it "calls LLM service for designated steps" do
    llm_steps.each do |step_name|
      expect_any_instance_of(described_class).to receive(:execute_llm_task)
        .with(step_name, anything)
        .and_return(mock_llm_response)
    end
    
    workflow_instance.execute
  end
  
  it "handles LLM service failures" do
    llm_steps.each do |step_name|
      allow_any_instance_of(described_class).to receive(:execute_llm_task)
        .with(step_name, anything)
        .and_raise(SuperAgent::LLMError, "LLM service unavailable")
    end
    
    result = workflow_instance.execute
    expect(result).to be_failed
    expect(result.error_type).to eq(:llm_error)
  end
  
  it "tracks LLM usage and costs" do
    workflow_instance.execute
    
    expect(workflow_instance.llm_calls_made).to eq(llm_steps.length)
    expect(workflow_instance.estimated_cost).to be > 0 if llm_steps.any?
  end
end

RSpec.shared_examples "a workflow with streaming updates" do
  it "supports streaming updates" do
    expect(workflow_instance).to respond_to(:stream_update)
  end
  
  it "broadcasts progress updates" do
    expect(workflow_instance).to receive(:stream_update).at_least(:once)
    workflow_instance.execute
  end
  
  it "includes step information in updates" do
    updates_received = []
    
    allow(workflow_instance).to receive(:stream_update) do |update|
      updates_received << update
    end
    
    workflow_instance.execute
    
    expect(updates_received).not_to be_empty
    updates_received.each do |update|
      expect(update).to have_key(:step)
      expect(update).to have_key(:status)
    end
  end
end

RSpec.shared_examples "a SuperAgent agent" do |agent_class|
  let(:agent_instance) { agent_class.new }
  
  it "inherits from ApplicationAgent" do
    expect(agent_class.ancestors).to include(ApplicationAgent)
  end
  
  it "has defined workflows" do
    expect(agent_instance).to respond_to(:available_workflows)
    expect(agent_instance.available_workflows).to be_an(Array)
  end
  
  describe "workflow coordination" do
    it "can trigger workflows" do
      expect(agent_instance).to respond_to(:execute_workflow)
    end
    
    it "selects appropriate workflow based on context" do
      # This would be specific to each agent implementation
      if agent_instance.respond_to?(:select_workflow)
        workflow = agent_instance.select_workflow({})
        expect(workflow).to be_present
      end
    end
    
    it "handles workflow failures gracefully" do
      allow(agent_instance).to receive(:execute_workflow).and_raise(StandardError, "Workflow failed")
      
      expect { agent_instance.process({}) }.not_to raise_error
    end
  end
  
  describe "decision making" do
    it "makes decisions based on input context" do
      if agent_instance.respond_to?(:make_decision)
        decision = agent_instance.make_decision({})
        expect(decision).to be_present
      end
    end
    
    it "provides reasoning for decisions" do
      if agent_instance.respond_to?(:decision_reasoning)
        reasoning = agent_instance.decision_reasoning
        expect(reasoning).to be_a(String)
      end
    end
  end
  
  describe "error handling" do
    it "logs errors appropriately" do
      expect(Rails.logger).to receive(:error).at_least(:once)
      
      allow(agent_instance).to receive(:execute_workflow).and_raise(StandardError, "Test error")
      agent_instance.process({}) rescue nil
    end
    
    it "provides fallback behavior on errors" do
      allow(agent_instance).to receive(:execute_workflow).and_raise(StandardError, "Test error")
      
      result = agent_instance.process({})
      expect(result).to have_key(:error)
      expect(result).to have_key(:fallback_action)
    end
  end
end

RSpec.shared_examples "an agent with background job integration" do
  it "can queue background jobs" do
    expect(agent_instance).to respond_to(:queue_job)
  end
  
  it "queues jobs to appropriate queues" do
    job_class = double("JobClass")
    allow(job_class).to receive(:perform_async)
    
    agent_instance.queue_job(job_class, {})
    
    expect(job_class).to have_received(:perform_async)
  end
  
  it "handles job queueing failures" do
    job_class = double("JobClass")
    allow(job_class).to receive(:perform_async).and_raise(StandardError, "Queue error")
    
    expect { agent_instance.queue_job(job_class, {}) }.not_to raise_error
  end
end

RSpec.shared_examples "an agent with AI analysis capabilities" do
  let(:sample_data) { { "text" => "Sample text for analysis" } }
  
  it "can perform AI analysis" do
    expect(agent_instance).to respond_to(:analyze)
  end
  
  it "returns structured analysis results" do
    mock_llm_response({ "sentiment" => "positive", "confidence" => 0.9 })
    
    result = agent_instance.analyze(sample_data)
    
    expect(result).to be_a(Hash)
    expect(result).to have_key("sentiment")
    expect(result).to have_key("confidence")
  end
  
  it "handles analysis failures gracefully" do
    allow(SuperAgent::LLM).to receive(:call).and_raise(SuperAgent::LLMError, "Analysis failed")
    
    result = agent_instance.analyze(sample_data)
    
    expect(result).to have_key(:error)
    expect(result[:error]).to include("Analysis failed")
  end
  
  it "caches analysis results when appropriate" do
    mock_llm_response({ "sentiment" => "positive" })
    
    # First call
    result1 = agent_instance.analyze(sample_data)
    
    # Second call with same data should use cache
    expect(SuperAgent::LLM).not_to receive(:call)
    result2 = agent_instance.analyze(sample_data)
    
    expect(result1).to eq(result2)
  end
end

RSpec.shared_examples "a workflow with conditional logic" do |conditional_steps|
  conditional_steps.each do |step_name, conditions|
    describe "conditional step: #{step_name}" do
      it "executes when conditions are met" do
        # Set up conditions to be true
        conditions[:when_true].each do |condition, value|
          allow(workflow_instance).to receive(condition).and_return(value)
        end
        
        executed_steps = []
        allow_any_instance_of(described_class).to receive(:execute_step) do |_, step|
          executed_steps << step
          true
        end
        
        workflow_instance.execute
        
        expect(executed_steps).to include(step_name)
      end
      
      it "skips when conditions are not met" do
        # Set up conditions to be false
        conditions[:when_false].each do |condition, value|
          allow(workflow_instance).to receive(condition).and_return(value)
        end
        
        executed_steps = []
        allow_any_instance_of(described_class).to receive(:execute_step) do |_, step|
          executed_steps << step
          true
        end
        
        workflow_instance.execute
        
        expect(executed_steps).not_to include(step_name)
      end
    end
  end
end

RSpec.shared_examples "a workflow with data validation" do |validation_steps|
  validation_steps.each do |step_name, validation_rules|
    describe "validation step: #{step_name}" do
      it "validates required fields" do
        validation_rules[:required_fields].each do |field|
          invalid_inputs = workflow_inputs.except(field)
          invalid_workflow = described_class.new(invalid_inputs)
          
          result = invalid_workflow.execute
          expect(result).to be_failed
          expect(result.validation_errors).to include(field)
        end
      end
      
      it "validates field formats" do
        validation_rules[:format_validations].each do |field, format_rule|
          invalid_inputs = workflow_inputs.merge(field => "invalid_format")
          invalid_workflow = described_class.new(invalid_inputs)
          
          result = invalid_workflow.execute
          expect(result).to be_failed
          expect(result.validation_errors[field]).to include("format")
        end
      end if validation_rules[:format_validations]
    end
  end
end