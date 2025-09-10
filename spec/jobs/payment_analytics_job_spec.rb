# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentAnalyticsJob, type: :job do
  let(:user) { create(:user) }
  let(:event_type) { 'payment_setup_started' }
  let(:context) { { template_id: '123', action: 'clicked' } }

  describe '#perform' do
    it 'calls PaymentAnalyticsService with correct parameters' do
      service_double = instance_double(PaymentAnalyticsService)
      allow(PaymentAnalyticsService).to receive(:new).and_return(service_double)
      
      expect(service_double).to receive(:track_event).with(
        event_type,
        user: user,
        context: context
      )
      
      described_class.new.perform(event_type, user.id, context)
    end

    it 'creates analytics record' do
      expect {
        described_class.new.perform(event_type, user.id, context)
      }.to change(PaymentAnalytic, :count).by(1)
    end

    context 'when user is not found' do
      it 'logs error and does not retry' do
        expect(Rails.logger).to receive(:error).with(/User not found/)
        
        expect {
          described_class.new.perform(event_type, 'nonexistent-id', context)
        }.not_to raise_error
      end

      it 'does not create analytics record' do
        expect {
          described_class.new.perform(event_type, 'nonexistent-id', context)
        }.not_to change(PaymentAnalytic, :count)
      end
    end

    context 'when service fails' do
      before do
        allow_any_instance_of(PaymentAnalyticsService).to receive(:track_event)
          .and_raise(StandardError.new('Service error'))
      end

      it 'logs error and re-raises for retry' do
        expect(Rails.logger).to receive(:error).with(/PaymentAnalyticsJob failed/)
        
        expect {
          described_class.new.perform(event_type, user.id, context)
        }.to raise_error(StandardError, 'Service error')
      end
    end
  end

  describe 'job configuration' do
    it 'uses analytics queue' do
      expect(described_class.queue_name).to eq('analytics')
    end

    it 'has retry configuration' do
      expect(described_class.retry_on).to include(StandardError)
    end
  end

  describe 'integration with Sidekiq' do
    it 'enqueues job correctly' do
      expect {
        PaymentAnalyticsJob.perform_async(event_type, user.id, context)
      }.to change(PaymentAnalyticsJob.jobs, :size).by(1)
    end

    it 'processes job with correct arguments' do
      PaymentAnalyticsJob.perform_async(event_type, user.id, context)
      
      job = PaymentAnalyticsJob.jobs.last
      expect(job['args']).to eq([event_type, user.id, context.stringify_keys])
    end
  end
end