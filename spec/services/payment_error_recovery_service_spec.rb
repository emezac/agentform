# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentErrorRecoveryService, type: :service do
  let(:user) { create(:user) }
  let(:context) { { return_url: '/forms/123', form_edit_url: '/forms/123/edit' } }

  describe '#call' do
    context 'with stripe_not_configured error' do
      let(:error) { PaymentValidationErrors.stripe_not_configured }
      let(:service) { described_class.new(error: error, user: user, context: context) }

      it 'generates stripe setup workflow' do
        result = service.call
        
        expect(result).to be_success
        
        workflow = result.recovery_workflow
        expect(workflow[:error_type]).to eq('stripe_not_configured')
        expect(workflow[:total_steps]).to eq(3)
        expect(workflow[:steps]).to all(include(:id, :title, :description, :action_url, :estimated_minutes))
        
        step_ids = workflow[:steps].map { |step| step[:id] }
        expect(step_ids).to eq(['stripe_account_creation', 'stripe_webhook_configuration', 'stripe_test_payment'])
      end

      it 'includes detailed help content for each step' do
        result = service.call
        
        workflow = result.recovery_workflow
        workflow[:steps].each do |step|
          expect(step[:help_content]).to include(:overview, :steps)
          expect(step[:help_content][:steps]).to be_an(Array)
          expect(step[:help_content][:steps]).not_to be_empty
        end
      end

      it 'calculates estimated time correctly' do
        result = service.call
        
        workflow = result.recovery_workflow
        expected_time = workflow[:steps].sum { |step| step[:estimated_minutes] }
        expect(workflow[:estimated_time]).to eq(expected_time)
        expect(workflow[:estimated_time]).to eq(7) # 3 + 2 + 2 minutes
      end
    end

    context 'with premium_subscription_required error' do
      let(:error) { PaymentValidationErrors.premium_required }
      let(:service) { described_class.new(error: error, user: user, context: context) }

      it 'generates subscription upgrade workflow' do
        result = service.call
        
        workflow = result.recovery_workflow
        expect(workflow[:error_type]).to eq('premium_subscription_required')
        expect(workflow[:total_steps]).to eq(3)
        
        step_ids = workflow[:steps].map { |step| step[:id] }
        expect(step_ids).to eq(['review_premium_features', 'select_premium_plan', 'verify_premium_access'])
      end

      it 'includes premium features information' do
        result = service.call
        
        workflow = result.recovery_workflow
        first_step = workflow[:steps].first
        expect(first_step[:help_content][:features]).to be_an(Array)
        expect(first_step[:help_content][:features]).to include(
          match(/payment forms/),
          match(/analytics/),
          match(/branding/)
        )
      end
    end

    context 'with multiple_requirements_missing error' do
      let(:error) do
        PaymentValidationErrors.multiple_requirements(
          ['stripe_configuration', 'premium_subscription']
        )
      end
      let(:service) { described_class.new(error: error, user: user, context: context) }

      it 'combines workflows from multiple requirements' do
        result = service.call
        
        workflow = result.recovery_workflow
        expect(workflow[:error_type]).to eq('multiple_requirements_missing')
        expect(workflow[:total_steps]).to be > 3 # Should have steps from both workflows
        
        step_ids = workflow[:steps].map { |step| step[:id] }
        expect(step_ids).to include('review_premium_features', 'stripe_account_creation', 'final_verification')
      end

      it 'includes final verification step' do
        result = service.call
        
        workflow = result.recovery_workflow
        final_step = workflow[:steps].last
        expect(final_step[:id]).to eq('final_verification')
        expect(final_step[:title]).to include('Final Setup Verification')
      end
    end

    context 'with invalid_payment_configuration error' do
      let(:error) { PaymentValidationErrors.invalid_payment_configuration }
      let(:service) { described_class.new(error: error, user: user, context: context) }

      it 'generates configuration fix workflow' do
        result = service.call
        
        workflow = result.recovery_workflow
        expect(workflow[:error_type]).to eq('invalid_payment_configuration')
        expect(workflow[:total_steps]).to eq(2)
        
        step_ids = workflow[:steps].map { |step| step[:id] }
        expect(step_ids).to eq(['review_payment_questions', 'test_payment_questions'])
      end

      it 'uses context URLs for form editing' do
        result = service.call
        
        workflow = result.recovery_workflow
        first_step = workflow[:steps].first
        expect(first_step[:action_url]).to eq('/forms/123/edit')
      end
    end

    context 'with unknown error type' do
      let(:error) { double(error_type: 'unknown_error', user_guidance: {}) }
      let(:service) { described_class.new(error: error, user: user, context: context) }

      it 'generates generic recovery workflow' do
        result = service.call
        
        workflow = result.recovery_workflow
        expect(workflow[:total_steps]).to eq(1)
        expect(workflow[:steps].first[:id]).to eq('contact_support')
      end
    end

    context 'when workflow generation fails' do
      let(:error) { PaymentValidationErrors.stripe_not_configured }
      let(:service) { described_class.new(error: error, user: user, context: context) }

      before do
        allow(service).to receive(:generate_recovery_workflow).and_raise(StandardError, 'Generation failed')
      end

      it 'returns error result' do
        result = service.call
        
        expect(result).to be_error
        expect(result.message).to eq('Could not generate recovery workflow')
        expect(result.details).to eq('Generation failed')
      end
    end
  end

  describe '.get_next_step' do
    let(:error_type) { 'stripe_not_configured' }
    let(:completed_steps) { ['stripe_account_creation'] }

    it 'returns the next incomplete step' do
      next_step = described_class.get_next_step(
        error_type: error_type,
        user: user,
        completed_steps: completed_steps
      )
      
      expect(next_step[:id]).to eq('stripe_webhook_configuration')
      expect(next_step).to include(:title, :description, :action_url)
    end

    context 'when all steps are completed' do
      let(:completed_steps) { ['stripe_account_creation', 'stripe_webhook_configuration', 'stripe_test_payment'] }

      it 'returns nil' do
        next_step = described_class.get_next_step(
          error_type: error_type,
          user: user,
          completed_steps: completed_steps
        )
        
        expect(next_step).to be_nil
      end
    end
  end

  describe '.mark_step_completed' do
    let(:error_type) { 'stripe_not_configured' }
    let(:step_id) { 'stripe_account_creation' }

    it 'marks step as completed' do
      expect(Rails.logger).to receive(:info).with("Marking step #{step_id} as completed for user #{user.id}")
      
      result = described_class.mark_step_completed(
        error_type: error_type,
        user: user,
        step_id: step_id
      )
      
      expect(result).to be true
    end

    context 'with Rails.cache available' do
      before do
        allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      end

      it 'stores completed steps in cache' do
        described_class.mark_step_completed(
          error_type: error_type,
          user: user,
          step_id: step_id
        )
        
        cache_key = "payment_recovery:#{user.id}:#{error_type}"
        completed_steps = Rails.cache.read(cache_key)
        expect(completed_steps).to include(step_id)
      end

      it 'does not duplicate completed steps' do
        # Mark the same step twice
        2.times do
          described_class.mark_step_completed(
            error_type: error_type,
            user: user,
            step_id: step_id
          )
        end
        
        cache_key = "payment_recovery:#{user.id}:#{error_type}"
        completed_steps = Rails.cache.read(cache_key)
        expect(completed_steps.count(step_id)).to eq(1)
      end
    end
  end

  describe 'private workflow generation methods' do
    let(:error) { PaymentValidationErrors.stripe_not_configured }
    let(:service) { described_class.new(error: error, user: user, context: context) }

    describe '#generate_stripe_setup_workflow' do
      it 'creates steps with proper dependencies' do
        service.send(:generate_stripe_setup_workflow)
        steps = service.instance_variable_get(:@recovery_steps)
        
        webhook_step = steps.find { |s| s[:id] == 'stripe_webhook_configuration' }
        expect(webhook_step[:requirements]).to include('stripe_account_creation')
        
        test_step = steps.find { |s| s[:id] == 'stripe_test_payment' }
        expect(test_step[:requirements]).to include('stripe_account_creation', 'stripe_webhook_configuration')
      end

      it 'includes validation endpoints for each step' do
        service.send(:generate_stripe_setup_workflow)
        steps = service.instance_variable_get(:@recovery_steps)
        
        steps.each do |step|
          expect(step[:validation_endpoint]).to be_present
          expect(step[:validation_endpoint]).to start_with('/api/v1/')
        end
      end
    end

    describe '#calculate_estimated_time' do
      before do
        service.instance_variable_set(:@recovery_steps, [
          { estimated_minutes: 3 },
          { estimated_minutes: 2 },
          { estimated_minutes: 5 }
        ])
      end

      it 'sums up estimated minutes from all steps' do
        total_time = service.send(:calculate_estimated_time)
        expect(total_time).to eq(10)
      end
    end

    describe '#generate_completion_url' do
      it 'uses context return_url when available' do
        completion_url = service.send(:generate_completion_url)
        expect(completion_url).to eq('/forms/123')
      end

      context 'without context return_url' do
        let(:context) { {} }

        it 'uses default forms path' do
          completion_url = service.send(:generate_completion_url)
          expect(completion_url).to eq('/forms')
        end
      end
    end
  end

  describe 'caching and tracking' do
    let(:error) { PaymentValidationErrors.stripe_not_configured }
    let(:service) { described_class.new(error: error, user: user, context: context) }

    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    end

    it 'tracks recovery initiation in cache' do
      service.call
      
      cache_key = "payment_recovery_started:#{user.id}:#{error.error_type}"
      cached_data = Rails.cache.read(cache_key)
      
      expect(cached_data).to include(
        :started_at,
        error_type: error.error_type,
        total_steps: 3
      )
      expect(cached_data[:started_at]).to be_within(1.second).of(Time.current)
    end
  end
end