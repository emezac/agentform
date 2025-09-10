# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserMailer, type: :mailer do
  let(:user) { create(:user, first_name: 'John', last_name: 'Doe', email: 'john.doe@example.com') }
  let(:temporary_password) { 'temp123456' }
  let(:suspension_reason) { 'Violation of terms of service' }

  describe '#admin_invitation' do
    let(:mail) { UserMailer.admin_invitation(user, temporary_password) }

    it 'renders the headers' do
      expect(mail.subject).to eq('Welcome to AgentForm - Your Account Has Been Created')
      expect(mail.to).to eq([user.email])
      expect(mail.from).to eq(['noreply@agentform.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to include(user.first_name)
      expect(mail.body.encoded).to include(user.email)
      expect(mail.body.encoded).to include(temporary_password)
      expect(mail.body.encoded).to include('temporary password')
    end

    it 'includes login URL' do
      expect(mail.body.encoded).to include('Log In to AgentForm')
    end

    it 'includes security warning' do
      expect(mail.body.encoded).to include('temporary password')
      expect(mail.body.encoded).to include('change it when you first log in')
    end
  end

  describe '#account_suspended' do
    let(:mail) { UserMailer.account_suspended(user, suspension_reason) }

    it 'renders the headers' do
      expect(mail.subject).to eq('AgentForm Account Suspended')
      expect(mail.to).to eq([user.email])
      expect(mail.from).to eq(['noreply@agentform.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to include(user.first_name)
      expect(mail.body.encoded).to include(user.email)
      expect(mail.body.encoded).to include(suspension_reason)
      expect(mail.body.encoded).to include('suspended')
    end

    it 'includes contact information' do
      expect(mail.body.encoded).to include('support@agentform.com')
    end

    it 'explains suspension consequences' do
      expect(mail.body.encoded).to include('cannot log in')
      expect(mail.body.encoded).to include('temporarily inaccessible')
    end
  end

  describe '#account_reactivated' do
    let(:mail) { UserMailer.account_reactivated(user) }

    it 'renders the headers' do
      expect(mail.subject).to eq('AgentForm Account Reactivated')
      expect(mail.to).to eq([user.email])
      expect(mail.from).to eq(['noreply@agentform.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to include(user.first_name)
      expect(mail.body.encoded).to include(user.email)
      expect(mail.body.encoded).to include('reactivated')
      expect(mail.body.encoded).to include('Welcome Back')
    end

    it 'includes login URL' do
      expect(mail.body.encoded).to include('Log In to AgentForm')
    end

    it 'explains restored access' do
      expect(mail.body.encoded).to include('full access')
      expect(mail.body.encoded).to include('preserved')
    end
  end

  describe 'email delivery' do
    it 'delivers admin invitation email' do
      expect {
        UserMailer.admin_invitation(user, temporary_password).deliver_now
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it 'delivers suspension notification email' do
      expect {
        UserMailer.account_suspended(user, suspension_reason).deliver_now
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it 'delivers reactivation notification email' do
      expect {
        UserMailer.account_reactivated(user).deliver_now
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end
end