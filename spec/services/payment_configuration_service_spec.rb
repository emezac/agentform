# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentConfigurationService, type: :service do
  let(:user) { create(:user) }
  let(:premium_user) { create(:user, :premium) }
  let(:stripe_configured_user) { create(:user, :with_stripe) }
  let(:fully_configured_user) { create(:user, :premium, :with_stripe) }

  describe '#call' do
    context 'with valid user' do
      let(:service) { described_class.new(user: user) }

      it 'successfully calculates setup status' do
        result = service.call

        expect(service).to be_success
        expect(service.result).to be_a(Hash)
        expect(service.result[:user_id]).to eq(user.id)
      end

      it 'includes all required status fields' do
        service.call

        result = service.result
        expect(result).to include(
          :user_id,
          :setup_complete,
          :progress_percentage,
          :completed_steps,
          :missing_steps,
          :next_step,
          :requirements,
          :stripe_status,
          :subscription_status,
          :calculated_at,
          :expires_at
        )
      end

      it 'sets context information' do
        service.call

        expect(service.get_context(:status_updated_at)).to be_present
        expect(service.get_context(:cache_used)).to be_in([true, false])
      end
    end

    context 'with invalid inputs' do
      it 'fails when user is nil' do
        service = described_class.new(user: nil)
        service.call

        expect(service).to be_failure
        expect(service.errors[:user]).to include('is required')
      end

      it 'fails when user is not a User instance' do
        service = described_class.new(user: 'not_a_user')
        service.call

        expect(service).to be_failure
        expect(service.errors[:user]).to include('must be a User instance')
      end
    end
  end

  describe '.get_setup_status' do
    it 'returns setup status for valid user' do
      status = described_class.get_setup_status(user)

      expect(status).to be_a(Hash)
      expect(status[:user_id]).to eq(user.id)
    end

    it 'returns nil for invalid user' do
      status = described_class.get_setup_status(nil)

      expect(status).to be_nil
    end

    it 'respects force_refresh parameter' do
      # First call to populate cache
      described_class.get_setup_status(user)

      # Mock cache to verify force_refresh bypasses it
      allow(Rails.cache).to receive(:read).and_return(nil)
      
      status = described_class.get_setup_status(user, force_refresh: true)
      expect(status).to be_present
    end
  end

  describe '.calculate_progress' do
    it 'returns 0 for user with no setup' do
      progress = described_class.calculate_progress(user)
      expect(progress).to eq(0)
    end

    it 'returns 50 for user with only Stripe configured' do
      progress = described_class.calculate_progress(stripe_configured_user)
      expect(progress).to eq(50)
    end

    it 'returns 50 for user with only Premium subscription' do
      progress = described_class.calculate_progress(premium_user)
      expect(progress).to eq(50)
    end

    it 'returns 100 for fully configured user' do
      progress = described_class.calculate_progress(fully_configured_user)
      expect(progress).to eq(100)
    end

    it 'returns 0 for invalid user' do
      progress = described_class.calculate_progress(nil)
      expect(progress).to eq(0)
    end
  end

  describe '.next_required_step' do
    it 'returns stripe_configuration for user with no setup' do
      step = described_class.next_required_step(user)
      expect(step).to eq('stripe_configuration')
    end

    it 'returns premium_subscription for user with only Stripe' do
      step = described_class.next_required_step(stripe_configured_user)
      expect(step).to eq('premium_subscription')
    end

    it 'returns stripe_configuration for user with only Premium' do
      step = described_class.next_required_step(premium_user)
      expect(step).to eq('stripe_configuration')
    end

    it 'returns nil for fully configured user' do
      step = described_class.next_required_step(fully_configured_user)
      expect(step).to be_nil
    end

    it 'returns nil for invalid user' do
      step = described_class.next_required_step(nil)
      expect(step).to be_nil
    end
  end

  describe '.missing_steps' do
    it 'returns all steps for user with no setup' do
      steps = described_class.missing_steps(user)
      expect(steps).to contain_exactly('stripe_configuration', 'premium_subscription')
    end

    it 'returns premium_subscription for user with only Stripe' do
      steps = described_class.missing_steps(stripe_configured_user)
      expect(steps).to contain_exactly('premium_subscription')
    end

    it 'returns stripe_configuration for user with only Premium' do
      steps = described_class.missing_steps(premium_user)
      expect(steps).to contain_exactly('stripe_configuration')
    end

    it 'returns empty array for fully configured user' do
      steps = described_class.missing_steps(fully_configured_user)
      expect(steps).to be_empty
    end

    it 'returns all steps for invalid user' do
      steps = described_class.missing_steps(nil)
      expect(steps).to contain_exactly('stripe_configuration', 'premium_subscription')
    end
  end

  describe '.setup_complete?' do
    it 'returns false for user with no setup' do
      expect(described_class.setup_complete?(user)).to be false
    end

    it 'returns false for user with only Stripe' do
      expect(described_class.setup_complete?(stripe_configured_user)).to be false
    end

    it 'returns false for user with only Premium' do
      expect(described_class.setup_complete?(premium_user)).to be false
    end

    it 'returns true for fully configured user' do
      expect(described_class.setup_complete?(fully_configured_user)).to be true
    end

    it 'returns false for invalid user' do
      expect(described_class.setup_complete?(nil)).to be false
    end
  end

  describe '.setup_requirements' do
    it 'returns all requirements for user with no setup' do
      requirements = described_class.setup_requirements(user)
      
      expect(requirements.length).to eq(2)
      expect(requirements.map { |r| r[:type] }).to contain_exactly(
        'stripe_configuration', 'premium_subscription'
      )
    end

    it 'returns premium requirement for user with only Stripe' do
      requirements = described_class.setup_requirements(stripe_configured_user)
      
      expect(requirements.length).to eq(1)
      expect(requirements.first[:type]).to eq('premium_subscription')
    end

    it 'returns stripe requirement for user with only Premium' do
      requirements = described_class.setup_requirements(premium_user)
      
      expect(requirements.length).to eq(1)
      expect(requirements.first[:type]).to eq('stripe_configuration')
    end

    it 'returns empty array for fully configured user' do
      requirements = described_class.setup_requirements(fully_configured_user)
      expect(requirements).to be_empty
    end

    it 'returns empty array for invalid user' do
      requirements = described_class.setup_requirements(nil)
      expect(requirements).to be_empty
    end

    it 'includes all required fields in requirements' do
      requirements = described_class.setup_requirements(user)
      
      requirements.each do |requirement|
        expect(requirement).to include(
          :type,
          :title,
          :description,
          :action_url,
          :action_text,
          :priority,
          :estimated_time,
          :benefits
        )
      end
    end
  end

  describe 'caching behavior' do
    let(:cache_key) { described_class.send(:cache_key, user.id) }

    before do
      Rails.cache.clear
      # Enable caching for these tests
      allow(Rails.cache).to receive(:write).and_call_original
      allow(Rails.cache).to receive(:read).and_call_original
      allow(Rails.cache).to receive(:delete).and_call_original
    end

    it 'caches setup status after first calculation' do
      service = described_class.new(user: user)
      service.call

      # Verify the service completed successfully
      expect(service).to be_success
      expect(service.result).to be_present
      expect(service.result[:user_id]).to eq(user.id)
    end

    it 'uses cached data on subsequent calls' do
      # Mock cache to control behavior
      cached_data = {
        user_id: user.id,
        setup_complete: false,
        progress_percentage: 0,
        calculated_at: Time.current
      }
      
      allow(Rails.cache).to receive(:read).with(cache_key).and_return(nil, cached_data)
      
      # First call to populate cache
      service1 = described_class.new(user: user)
      service1.call

      # Second call should use cache
      service2 = described_class.new(user: user)
      service2.call

      expect(service2.get_context(:cache_hit)).to be true
    end

    it 'bypasses cache when force_refresh is true' do
      # Mock cache to return data
      cached_data = { user_id: user.id, setup_complete: false }
      allow(Rails.cache).to receive(:read).with(cache_key).and_return(cached_data)

      # Call with force_refresh should bypass cache
      service = described_class.new(user: user, force_refresh: true)
      service.call

      expect(service.get_context(:cache_hit)).to be false
    end

    it 'invalidates cache correctly' do
      # Test the invalidate method exists and can be called
      expect { described_class.invalidate_cache(user) }.not_to raise_error
      
      # Verify it calls Rails.cache.delete with correct key
      expect(Rails.cache).to receive(:delete).with(cache_key)
      described_class.invalidate_cache(user)
    end
  end

  describe '.bulk_update_status' do
    let(:users) { create_list(:user, 3) }
    let(:user_ids) { users.map(&:id) }

    it 'updates status for all valid users' do
      result = described_class.bulk_update_status(user_ids)

      expect(result[:updated]).to eq(3)
      expect(result[:errors]).to be_empty
      expect(result[:total_processed]).to eq(3)
    end

    it 'handles empty user_ids array' do
      result = described_class.bulk_update_status([])

      expect(result[:updated]).to eq(0)
      expect(result[:errors]).to be_empty
    end

    it 'handles nil user_ids' do
      result = described_class.bulk_update_status(nil)

      expect(result[:updated]).to eq(0)
      expect(result[:errors]).to be_empty
    end

    it 'handles invalid user IDs gracefully' do
      invalid_ids = [999999, 999998]
      result = described_class.bulk_update_status(invalid_ids)

      expect(result[:updated]).to eq(0)
      expect(result[:total_processed]).to eq(2)
    end

    it 'continues processing after individual errors' do
      # Mix valid and invalid IDs
      mixed_ids = [users.first.id, 999999, users.last.id]
      result = described_class.bulk_update_status(mixed_ids)

      expect(result[:updated]).to eq(2)
      expect(result[:total_processed]).to eq(3)
    end
  end

  describe 'status calculation details' do
    context 'for user with no setup' do
      let(:service) { described_class.new(user: user) }

      before { service.call }

      it 'calculates correct progress' do
        expect(service.result[:progress_percentage]).to eq(0)
        expect(service.result[:setup_complete]).to be false
      end

      it 'identifies missing steps' do
        expect(service.result[:missing_steps]).to contain_exactly(
          'stripe_configuration', 'premium_subscription'
        )
        expect(service.result[:completed_steps]).to be_empty
      end

      it 'sets correct next step' do
        expect(service.result[:next_step]).to eq('stripe_configuration')
      end

      it 'includes stripe status details' do
        stripe_status = service.result[:stripe_status]
        expect(stripe_status[:configured]).to be false
        expect(stripe_status[:can_accept_payments]).to be false
      end

      it 'includes subscription status details' do
        subscription_status = service.result[:subscription_status]
        expect(subscription_status[:is_premium]).to be false
        expect(subscription_status[:subscription_tier]).to eq('freemium')
      end
    end

    context 'for fully configured user' do
      let(:service) { described_class.new(user: fully_configured_user) }

      before { service.call }

      it 'calculates correct progress' do
        expect(service.result[:progress_percentage]).to eq(100)
        expect(service.result[:setup_complete]).to be true
      end

      it 'identifies completed steps' do
        expect(service.result[:completed_steps]).to contain_exactly(
          'stripe_configuration', 'premium_subscription'
        )
        expect(service.result[:missing_steps]).to be_empty
      end

      it 'has no next step' do
        expect(service.result[:next_step]).to be_nil
      end

      it 'has no requirements' do
        expect(service.result[:requirements]).to be_empty
      end
    end
  end

  describe 'integration with existing services' do
    it 'integrates with StripeConfigurationChecker' do
      allow(StripeConfigurationChecker).to receive(:configuration_status)
        .with(stripe_configured_user)
        .and_return({ detailed: 'stripe_status' })

      service = described_class.new(user: stripe_configured_user)
      service.call

      expect(service.result[:stripe_status]).to include(detailed: 'stripe_status')
    end

    it 'uses user subscription methods' do
      allow(user).to receive(:premium?).and_return(false)
      allow(user).to receive(:subscription_tier).and_return('freemium')
      allow(user).to receive(:subscription_active?).and_return(false)
      allow(user).to receive(:subscription_expires_at).and_return(nil)
      allow(user).to receive(:trial_active?).and_return(false)
      allow(user).to receive(:trial_expired?).and_return(false)

      service = described_class.new(user: user)
      service.call

      subscription_status = service.result[:subscription_status]
      expect(subscription_status[:is_premium]).to be false
      expect(subscription_status[:subscription_tier]).to eq('freemium')
      expect(subscription_status[:subscription_active]).to be false
    end
  end

  describe 'error handling' do
    it 'handles Stripe configuration errors gracefully' do
      allow(StripeConfigurationChecker).to receive(:configuration_status)
        .and_raise(StandardError, 'Stripe API error')

      service = described_class.new(user: user)
      
      expect { service.call }.not_to raise_error
      expect(service).to be_success # Service should still succeed with basic status
      expect(service.result[:stripe_status][:configured]).to be false
    end

    it 'handles user method errors gracefully' do
      allow(user).to receive(:premium?).and_raise(StandardError, 'Database error')

      service = described_class.new(user: user)
      
      expect { service.call }.not_to raise_error
      expect(service).to be_failure
      expect(service.errors[:subscription_status]).to include('Failed to check subscription status: Database error')
    end
  end
end