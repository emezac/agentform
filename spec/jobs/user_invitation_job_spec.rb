# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserInvitationJob, type: :job do
  let(:user) { create(:user) }
  let(:temporary_password) { 'temp123456' }

  describe '#perform' do
    it 'sends invitation email' do
      expect(UserMailer).to receive(:admin_invitation).with(user, temporary_password).and_call_original
      expect_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_now)

      UserInvitationJob.perform_now(user.id, temporary_password)
    end

    it 'logs successful email sending' do
      allow(UserMailer).to receive(:admin_invitation).and_return(double(deliver_now: true))
      
      expect(Rails.logger).to receive(:info).with("Invitation email sent to #{user.email}")
      
      UserInvitationJob.perform_now(user.id, temporary_password)
    end

    context 'when user is not found' do
      it 'logs error and does not raise exception' do
        expect(Rails.logger).to receive(:error).with("User with ID 999999 not found for invitation email")
        
        expect {
          UserInvitationJob.perform_now(999999, temporary_password)
        }.not_to raise_error
      end
    end

    context 'when email delivery fails' do
      it 'logs error and raises exception for retry' do
        allow(UserMailer).to receive(:admin_invitation).and_raise(StandardError.new('SMTP Error'))
        
        expect(Rails.logger).to receive(:error).with("Failed to send invitation email to user #{user.id}: SMTP Error")
        
        expect {
          UserInvitationJob.perform_now(user.id, temporary_password)
        }.to raise_error(StandardError, 'SMTP Error')
      end
    end
  end

  describe 'job configuration' do
    it 'is queued on default queue' do
      expect(UserInvitationJob.queue_name).to eq('default')
    end

    it 'has retry configuration' do
      expect(UserInvitationJob.retry_on_exceptions).to include(StandardError)
    end
  end
end