# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserReactivationJob, type: :job do
  let(:user) { create(:user) }

  describe '#perform' do
    it 'sends reactivation notification email' do
      expect(UserMailer).to receive(:account_reactivated).with(user).and_call_original
      expect_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_now)

      UserReactivationJob.perform_now(user.id)
    end

    it 'logs successful email sending' do
      allow(UserMailer).to receive(:account_reactivated).and_return(double(deliver_now: true))
      
      expect(Rails.logger).to receive(:info).with("Reactivation notification email sent to #{user.email}")
      
      UserReactivationJob.perform_now(user.id)
    end

    context 'when user is not found' do
      it 'logs error and does not raise exception' do
        expect(Rails.logger).to receive(:error).with("User with ID 999999 not found for reactivation email")
        
        expect {
          UserReactivationJob.perform_now(999999)
        }.not_to raise_error
      end
    end

    context 'when email delivery fails' do
      it 'logs error and raises exception for retry' do
        allow(UserMailer).to receive(:account_reactivated).and_raise(StandardError.new('SMTP Error'))
        
        expect(Rails.logger).to receive(:error).with("Failed to send reactivation email to user #{user.id}: SMTP Error")
        
        expect {
          UserReactivationJob.perform_now(user.id)
        }.to raise_error(StandardError, 'SMTP Error')
      end
    end
  end

  describe 'job configuration' do
    it 'is queued on default queue' do
      expect(UserReactivationJob.queue_name).to eq('default')
    end

    it 'has retry configuration' do
      expect(UserReactivationJob.retry_on_exceptions).to include(StandardError)
    end
  end
end