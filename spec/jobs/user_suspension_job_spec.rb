# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserSuspensionJob, type: :job do
  let(:user) { create(:user) }
  let(:suspension_reason) { 'Violation of terms of service' }

  describe '#perform' do
    it 'sends suspension notification email' do
      expect(UserMailer).to receive(:account_suspended).with(user, suspension_reason).and_call_original
      expect_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_now)

      UserSuspensionJob.perform_now(user.id, suspension_reason)
    end

    it 'logs successful email sending' do
      allow(UserMailer).to receive(:account_suspended).and_return(double(deliver_now: true))
      
      expect(Rails.logger).to receive(:info).with("Suspension notification email sent to #{user.email}")
      
      UserSuspensionJob.perform_now(user.id, suspension_reason)
    end

    context 'when user is not found' do
      it 'logs error and does not raise exception' do
        expect(Rails.logger).to receive(:error).with("User with ID 999999 not found for suspension email")
        
        expect {
          UserSuspensionJob.perform_now(999999, suspension_reason)
        }.not_to raise_error
      end
    end

    context 'when email delivery fails' do
      it 'logs error and raises exception for retry' do
        allow(UserMailer).to receive(:account_suspended).and_raise(StandardError.new('SMTP Error'))
        
        expect(Rails.logger).to receive(:error).with("Failed to send suspension email to user #{user.id}: SMTP Error")
        
        expect {
          UserSuspensionJob.perform_now(user.id, suspension_reason)
        }.to raise_error(StandardError, 'SMTP Error')
      end
    end
  end

  describe 'job configuration' do
    it 'is queued on default queue' do
      expect(UserSuspensionJob.queue_name).to eq('default')
    end

    it 'has retry configuration' do
      expect(UserSuspensionJob.retry_on_exceptions).to include(StandardError)
    end
  end
end