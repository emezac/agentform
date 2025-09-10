# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ai::RetryMechanismService, type: :service do
  describe '.should_retry?' do
    it 'allows retries within limits' do
      expect(described_class.should_retry?('llm_error', 0)).to be true
      expect(described_class.should_retry?('llm_error', 2)).to be true
      expect(described_class.should_retry?('llm_error', 3)).to be false
    end

    it 'respects different retry limits for different error types' do
      expect(described_class.should_retry?('business_rules_error', 0)).to be true
      expect(described_class.should_retry?('business_rules_error', 1)).to be false
    end

    it 'returns false for unknown error types' do
      expect(described_class.should_retry?('unknown_error', 0)).to be false
    end
  end

  describe '.get_retry_delay' do
    it 'returns appropriate delays' do
      expect(described_class.get_retry_delay('llm_error', 0)).to eq(2)
      expect(described_class.get_retry_delay('llm_error', 1)).to eq(5)
      expect(described_class.get_retry_delay('llm_error', 2)).to eq(10)
      expect(described_class.get_retry_delay('llm_error', 5)).to eq(10) # Uses last value
    end

    it 'returns 0 for error types without delays' do
      expect(described_class.get_retry_delay('unknown_error', 0)).to eq(0)
    end
  end

  describe '.get_retry_strategy' do
    it 'returns correct strategies' do
      expect(described_class.get_retry_strategy('llm_error')).to eq('exponential_backoff')
      expect(described_class.get_retry_strategy('json_parse_error')).to eq('immediate_with_modification')
      expect(described_class.get_retry_strategy('unknown_error')).to eq('immediate')
    end
  end

  describe '.create_retry_plan' do
    context 'for retryable error' do
      it 'creates comprehensive retry plan' do
        plan = described_class.create_retry_plan('llm_error', 1, { current_model: 'gpt-4o' })

        expect(plan[:can_retry]).to be true
        expect(plan[:retry_count]).to eq(2)
        expect(plan[:delay_seconds]).to eq(5)
        expect(plan[:strategy]).to eq('exponential_backoff')
        expect(plan[:modifications]).to be_present
        expect(plan[:user_guidance]).to be_present
        expect(plan[:estimated_success_rate]).to be_present
      end

      it 'includes model fallback for LLM errors' do
        plan = described_class.create_retry_plan('llm_error', 0, { current_model: 'gpt-4o' })

        expect(plan[:modifications][:model_fallback]).to eq('gpt-4o-mini')
      end

      it 'includes question count limits for generation errors' do
        plan = described_class.create_retry_plan('generation_validation_error', 1)

        expect(plan[:modifications][:question_count_limit]).to eq(10)
        expect(plan[:modifications][:complexity_level]).to eq('simple')
      end
    end

    context 'for non-retryable error' do
      it 'returns nil' do
        plan = described_class.create_retry_plan('llm_error', 5) # Exceeds max retries

        expect(plan).to be_nil
      end
    end
  end

  describe '.execute_with_retry' do
    let(:operation_type) { 'test_operation' }
    let(:success_result) { { success: true, data: 'test' } }

    context 'when operation succeeds on first try' do
      it 'returns result without retry' do
        result = described_class.execute_with_retry(operation_type, 3) do |retry_count|
          expect(retry_count).to eq(0)
          success_result
        end

        expect(result).to eq(success_result)
      end
    end

    context 'when operation fails then succeeds' do
      it 'retries and returns success result' do
        call_count = 0
        
        result = described_class.execute_with_retry(operation_type, 3) do |retry_count|
          call_count += 1
          if call_count == 1
            raise JSON::ParserError, 'Invalid JSON'
          else
            success_result
          end
        end

        expect(result).to eq(success_result)
        expect(call_count).to eq(2)
      end
    end

    context 'when operation fails repeatedly' do
      it 'raises the last error after exhausting retries' do
        call_count = 0
        
        expect {
          described_class.execute_with_retry(operation_type, 2) do |retry_count|
            call_count += 1
            raise StandardError, "Attempt #{call_count}"
          end
        }.to raise_error(StandardError, 'Attempt 3')

        expect(call_count).to eq(3) # Initial + 2 retries
      end
    end

    context 'when error type should not be retried' do
      it 'raises error immediately' do
        call_count = 0
        
        expect {
          described_class.execute_with_retry(operation_type, 3) do |retry_count|
            call_count += 1
            # Simulate an error that shouldn't be retried
            error = StandardError.new('Business rule violation')
            allow(described_class).to receive(:classify_error).with(error).and_return('business_rules_error')
            allow(described_class).to receive(:should_retry?).with('business_rules_error', 0).and_return(false)
            raise error
          end
        }.to raise_error(StandardError, 'Business rule violation')

        expect(call_count).to eq(1) # No retries
      end
    end
  end

  describe '.classify_error' do
    it 'correctly classifies different error types' do
      expect(described_class.classify_error(JSON::ParserError.new)).to eq('json_parse_error')
      expect(described_class.classify_error(Net::TimeoutError.new)).to eq('timeout_error')
      expect(described_class.classify_error(SocketError.new)).to eq('network_error')
      expect(described_class.classify_error(ActiveRecord::RecordInvalid.new)).to eq('database_error')
      
      llm_error = StandardError.new('LLM processing failed')
      expect(described_class.classify_error(llm_error)).to eq('llm_error')
      
      validation_error = StandardError.new('validation failed')
      expect(described_class.classify_error(validation_error)).to eq('validation_error')
      
      generic_error = StandardError.new('something went wrong')
      expect(described_class.classify_error(generic_error)).to eq('unknown_error')
    end
  end

  describe 'retry modifications' do
    let(:service) { described_class.new(error_type: 'json_parse_error', retry_count: 1) }

    it 'provides appropriate modifications for JSON parse errors' do
      modifications = service.send(:get_retry_modifications)

      expect(modifications[:llm_temperature]).to eq(0.0)
      expect(modifications[:response_format]).to eq('strict_json')
    end

    it 'provides user guidance for retries' do
      guidance = service.send(:get_user_retry_guidance)

      expect(guidance).to include('adjusted AI parameters')
    end

    it 'determines auto-retry appropriately' do
      auto_retry_service = described_class.new(error_type: 'llm_error', retry_count: 1)
      manual_retry_service = described_class.new(error_type: 'content_length_error', retry_count: 1)

      expect(auto_retry_service.send(:should_auto_retry?)).to be true
      expect(manual_retry_service.send(:should_auto_retry?)).to be false
    end

    it 'estimates success rates' do
      service = described_class.new(error_type: 'llm_error', retry_count: 0)
      success_rate = service.send(:estimate_success_rate)

      expect(success_rate).to eq(70)
    end
  end
end