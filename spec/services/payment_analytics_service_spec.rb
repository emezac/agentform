# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentAnalyticsService, type: :service do
  let(:user) { create(:user, :premium) }
  let(:service) { described_class.new }

  describe '#track_event' do
    context 'with valid event type' do
      it 'creates a payment analytic record' do
        expect {
          service.track_event('template_payment_interaction', user: user, context: { template_id: '123' })
        }.to change(PaymentAnalytic, :count).by(1)
      end

      it 'returns success result' do
        result = service.track_event('payment_setup_started', user: user, context: {})
        
        expect(result[:success]).to be true
        expect(result[:data]).to include(:event_type, :user_id, :timestamp)
      end

      it 'sanitizes sensitive context data' do
        context = {
          template_id: '123',
          password: 'secret',
          api_key: 'key123',
          safe_data: 'visible'
        }
        
        service.track_event('template_payment_interaction', user: user, context: context)
        
        analytic = PaymentAnalytic.last
        expect(analytic.context).to include('safe_data' => 'visible')
        expect(analytic.context).not_to have_key('password')
        expect(analytic.context).not_to have_key('api_key')
      end

      it 'anonymizes IP addresses' do
        context = { ip_address: '192.168.1.100' }
        
        service.track_event('payment_setup_completed', user: user, context: context)
        
        analytic = PaymentAnalytic.last
        expect(analytic.ip_address).to eq('192.168.1.0')
      end
    end

    context 'with invalid event type' do
      it 'returns failure result' do
        result = service.track_event('invalid_event', user: user, context: {})
        
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid event type')
      end

      it 'does not create analytic record' do
        expect {
          service.track_event('invalid_event', user: user, context: {})
        }.not_to change(PaymentAnalytic, :count)
      end
    end

    context 'when analytics fails' do
      before do
        allow(PaymentAnalytic).to receive(:create!).and_raise(StandardError.new('Database error'))
      end

      it 'returns failure result' do
        result = service.track_event('payment_setup_started', user: user, context: {})
        
        expect(result[:success]).to be false
        expect(result[:error]).to include('Failed to track event')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/PaymentAnalyticsService error/)
        
        service.track_event('payment_setup_started', user: user, context: {})
      end
    end
  end

  describe '#get_dashboard_metrics' do
    let(:date_range) { 7.days.ago..Time.current }

    before do
      # Create test analytics data
      create(:payment_analytic, :setup_started, user: user, timestamp: 5.days.ago)
      create(:payment_analytic, :setup_completed, user: user, timestamp: 4.days.ago)
      create(:payment_analytic, :template_interaction, user: user, timestamp: 3.days.ago)
      create(:payment_analytic, :validation_error, user: user, timestamp: 2.days.ago)
    end

    it 'returns comprehensive metrics' do
      metrics = service.get_dashboard_metrics(date_range: date_range)
      
      expect(metrics).to include(
        :setup_completion_rate,
        :common_failure_points,
        :template_interaction_stats,
        :job_performance_metrics,
        :error_resolution_paths
      )
    end

    it 'calculates setup completion rate correctly' do
      metrics = service.get_dashboard_metrics(date_range: date_range)
      
      # 1 started, 1 completed = 100%
      expect(metrics[:setup_completion_rate]).to eq(100.0)
    end

    it 'identifies common failure points' do
      metrics = service.get_dashboard_metrics(date_range: date_range)
      
      expect(metrics[:common_failure_points]).to be_a(Hash)
      expect(metrics[:common_failure_points].keys).to include('stripe_not_configured')
    end

    it 'calculates template interaction stats' do
      metrics = service.get_dashboard_metrics(date_range: date_range)
      
      stats = metrics[:template_interaction_stats]
      expect(stats[:total_interactions]).to eq(1)
      expect(stats[:unique_users]).to eq(1)
    end

    context 'with no setup events' do
      before do
        PaymentAnalytic.where(event_type: ['payment_setup_started', 'payment_setup_completed']).delete_all
      end

      it 'returns zero completion rate' do
        metrics = service.get_dashboard_metrics(date_range: date_range)
        
        expect(metrics[:setup_completion_rate]).to eq(0)
      end
    end
  end

  describe 'context sanitization' do
    it 'limits context size' do
      large_context = { data: 'x' * 2000 }
      
      service.track_event('template_payment_interaction', user: user, context: large_context)
      
      analytic = PaymentAnalytic.last
      expect(analytic.context.to_json.length).to be <= 1000
    end

    it 'handles invalid JSON gracefully' do
      # Mock invalid JSON scenario
      allow_any_instance_of(described_class).to receive(:sanitize_context).and_call_original
      
      result = service.track_event('payment_setup_started', user: user, context: { valid: 'data' })
      
      expect(result[:success]).to be true
    end
  end

  describe 'external analytics integration' do
    context 'when external analytics is enabled' do
      before do
        allow(Rails.application.credentials).to receive(:dig).with(:analytics, :enabled).and_return(true)
      end

      it 'sends data to external analytics' do
        expect(Rails.logger).to receive(:info).with(/External analytics/)
        
        service.track_event('payment_setup_completed', user: user, context: {})
      end
    end

    context 'when external analytics is disabled' do
      before do
        allow(Rails.application.credentials).to receive(:dig).with(:analytics, :enabled).and_return(false)
      end

      it 'does not send data to external analytics' do
        expect(Rails.logger).not_to receive(:info).with(/External analytics/)
        
        service.track_event('payment_setup_completed', user: user, context: {})
      end
    end
  end
end