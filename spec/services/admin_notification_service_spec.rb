require 'rails_helper'

RSpec.describe AdminNotificationService, type: :service do
  let(:user) { create(:user) }

  describe '.notify' do
    it 'creates a notification for valid event type' do
      expect {
        AdminNotificationService.notify(:user_registered, user: user)
      }.to change(AdminNotification, :count).by(1)
    end

    it 'does not create notification for invalid event type' do
      expect {
        AdminNotificationService.notify(:invalid_event, user: user)
      }.not_to change(AdminNotification, :count)
    end

    it 'does not create notification in test environment by default' do
      expect {
        AdminNotificationService.notify(:user_registered, user: user)
      }.not_to change(AdminNotification, :count)
    end

    it 'creates notification in test environment when forced' do
      expect {
        AdminNotificationService.notify(:user_registered, user: user, force_in_test: true)
      }.to change(AdminNotification, :count).by(1)
    end
  end

  describe 'duplicate prevention' do
    it 'prevents duplicate notifications within 5 minutes' do
      # Create first notification
      AdminNotificationService.notify(:user_registered, user: user, force_in_test: true)
      
      # Try to create duplicate within 5 minutes
      expect {
        AdminNotificationService.notify(:user_registered, user: user, force_in_test: true)
      }.not_to change(AdminNotification, :count)
    end

    it 'allows notification after 5 minutes' do
      # Create first notification
      AdminNotificationService.notify(:user_registered, user: user, force_in_test: true)
      
      # Travel forward in time
      travel 6.minutes do
        expect {
          AdminNotificationService.notify(:user_registered, user: user, force_in_test: true)
        }.to change(AdminNotification, :count).by(1)
      end
    end
  end

  describe 'specific event types' do
    before { allow(Rails.env).to receive(:test?).and_return(false) }

    describe 'user_registered' do
      it 'creates correct notification data' do
        AdminNotificationService.notify(:user_registered, user: user)
        
        notification = AdminNotification.last
        expect(notification.event_type).to eq('user_registered')
        expect(notification.title).to eq('New user registered')
        expect(notification.user).to eq(user)
        expect(notification.priority).to eq('normal')
        expect(notification.category).to eq('user_activity')
      end
    end

    describe 'user_upgraded' do
      it 'creates correct notification data' do
        AdminNotificationService.notify(:user_upgraded, 
          user: user, 
          from_plan: 'basic', 
          to_plan: 'premium'
        )
        
        notification = AdminNotification.last
        expect(notification.event_type).to eq('user_upgraded')
        expect(notification.priority).to eq('high')
        expect(notification.metadata['from_plan']).to eq('basic')
        expect(notification.metadata['to_plan']).to eq('premium')
      end
    end

    describe 'trial_expired' do
      it 'creates correct notification data' do
        AdminNotificationService.notify(:trial_expired, user: user)
        
        notification = AdminNotification.last
        expect(notification.event_type).to eq('trial_expired')
        expect(notification.priority).to eq('high')
        expect(notification.category).to eq('billing')
      end
    end

    describe 'payment_failed' do
      it 'creates correct notification data' do
        AdminNotificationService.notify(:payment_failed, 
          user: user, 
          amount: 29.99, 
          error_message: 'Card declined'
        )
        
        notification = AdminNotification.last
        expect(notification.event_type).to eq('payment_failed')
        expect(notification.priority).to eq('high')
        expect(notification.metadata['amount']).to eq(29.99)
        expect(notification.metadata['error_message']).to eq('Card declined')
      end
    end

    describe 'high_response_volume' do
      let(:form) { create(:form, user: user) }

      it 'creates correct notification data' do
        AdminNotificationService.notify(:high_response_volume, 
          user: user, 
          form: form, 
          response_count: 150
        )
        
        notification = AdminNotification.last
        expect(notification.event_type).to eq('high_response_volume')
        expect(notification.priority).to eq('normal')
        expect(notification.metadata['form_id']).to eq(form.id)
        expect(notification.metadata['response_count']).to eq(150)
      end
    end

    describe 'suspicious_activity' do
      it 'creates correct notification data' do
        AdminNotificationService.notify(:suspicious_activity, 
          user: user, 
          activity_type: 'multiple_failed_logins', 
          details: { ip: '192.168.1.1', attempts: 5 }
        )
        
        notification = AdminNotification.last
        expect(notification.event_type).to eq('suspicious_activity')
        expect(notification.priority).to eq('critical')
        expect(notification.category).to eq('security')
        expect(notification.metadata['activity_type']).to eq('multiple_failed_logins')
      end
    end
  end

  describe 'error handling' do
    before { allow(Rails.env).to receive(:test?).and_return(false) }

    it 'handles errors gracefully' do
      allow(AdminNotification).to receive(:notify_user_registered).and_raise(StandardError.new('Database error'))
      
      expect {
        AdminNotificationService.notify(:user_registered, user: user)
      }.not_to raise_error
      
      expect(AdminNotification.count).to eq(0)
    end

    it 'logs errors' do
      allow(AdminNotification).to receive(:notify_user_registered).and_raise(StandardError.new('Database error'))
      allow(Rails.logger).to receive(:error)
      
      AdminNotificationService.notify(:user_registered, user: user)
      
      expect(Rails.logger).to have_received(:error).with(/Failed to create admin notification/)
    end
  end
end