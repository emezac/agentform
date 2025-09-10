# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentAnalytic, type: :model do
  let(:user) { create(:user) }

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:event_type) }
    it { should validate_presence_of(:timestamp) }
    it { should validate_presence_of(:context) }
    
    it 'validates event_type inclusion' do
      valid_types = PaymentAnalyticsService::PAYMENT_EVENTS
      
      valid_types.each do |event_type|
        analytic = build(:payment_analytic, event_type: event_type, user: user)
        expect(analytic).to be_valid
      end
      
      invalid_analytic = build(:payment_analytic, event_type: 'invalid_event', user: user)
      expect(invalid_analytic).not_to be_valid
    end
  end

  describe 'scopes' do
    let!(:template_interaction) { create(:payment_analytic, :template_interaction, user: user) }
    let!(:setup_started) { create(:payment_analytic, :setup_started, user: user) }
    let!(:old_event) { create(:payment_analytic, :setup_completed, user: user, timestamp: 2.months.ago) }

    describe '.by_event_type' do
      it 'filters by event type' do
        results = described_class.by_event_type('template_payment_interaction')
        
        expect(results).to include(template_interaction)
        expect(results).not_to include(setup_started)
      end
    end

    describe '.by_date_range' do
      it 'filters by date range' do
        range = 1.month.ago..Time.current
        results = described_class.by_date_range(range)
        
        expect(results).to include(template_interaction, setup_started)
        expect(results).not_to include(old_event)
      end
    end

    describe '.by_user_tier' do
      let(:premium_user) { create(:user, :premium) }
      let!(:premium_event) { create(:payment_analytic, user: premium_user, user_subscription_tier: 'premium') }

      it 'filters by user subscription tier' do
        results = described_class.by_user_tier('premium')
        
        expect(results).to include(premium_event)
        expect(results).not_to include(template_interaction)
      end
    end
  end

  describe 'helper methods' do
    describe '#error_type' do
      context 'for validation error events' do
        let(:analytic) do
          create(:payment_analytic, :validation_error, user: user, 
                 context: { 'error_type' => 'stripe_not_configured' })
        end

        it 'returns the error type' do
          expect(analytic.error_type).to eq('stripe_not_configured')
        end
      end

      context 'for non-error events' do
        let(:analytic) { create(:payment_analytic, :template_interaction, user: user) }

        it 'returns nil' do
          expect(analytic.error_type).to be_nil
        end
      end
    end

    describe '#resolution_path' do
      context 'for validation error events' do
        let(:analytic) do
          create(:payment_analytic, :validation_error, user: user,
                 context: { 'resolution_path' => 'stripe_setup' })
        end

        it 'returns the resolution path' do
          expect(analytic.resolution_path).to eq('stripe_setup')
        end
      end
    end

    describe '#template_id' do
      context 'for template interaction events' do
        let(:analytic) do
          create(:payment_analytic, :template_interaction, user: user,
                 context: { 'template_id' => '123' })
        end

        it 'returns the template ID' do
          expect(analytic.template_id).to eq('123')
        end
      end
    end

    describe '#setup_step' do
      context 'for setup events' do
        let(:analytic) do
          create(:payment_analytic, :setup_started, user: user,
                 context: { 'setup_step' => 'stripe_configuration' })
        end

        it 'returns the setup step' do
          expect(analytic.setup_step).to eq('stripe_configuration')
        end
      end
    end
  end

  describe 'data integrity' do
    it 'stores context as JSONB' do
      context_data = { 
        template_id: '123',
        user_action: 'clicked_template',
        metadata: { source: 'gallery' }
      }
      
      analytic = create(:payment_analytic, user: user, context: context_data)
      
      expect(analytic.context).to eq(context_data.stringify_keys)
      expect(analytic.context['metadata']).to eq({ 'source' => 'gallery' })
    end

    it 'handles empty context' do
      analytic = create(:payment_analytic, user: user, context: {})
      
      expect(analytic.context).to eq({})
      expect(analytic).to be_valid
    end

    it 'stores timestamp accurately' do
      timestamp = Time.current
      analytic = create(:payment_analytic, user: user, timestamp: timestamp)
      
      expect(analytic.timestamp).to be_within(1.second).of(timestamp)
    end
  end
end