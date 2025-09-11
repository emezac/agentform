require 'rails_helper'

RSpec.describe 'AdminNotificationService Redis Resilience', type: :integration do
  let(:user) { create(:user) }

  describe 'Redis error handling' do
    before do
      # Ensure we're not in test mode for these tests
      allow(Rails.env).to receive(:test?).and_return(false)
    end

    it 'handles Redis connection failures during notification creation gracefully' do
      # Mock AdminNotification to raise Redis error
      allow(AdminNotification).to receive(:notify_user_registered)
        .and_raise(Redis::CannotConnectError.new('Connection refused'))
      
      # Mock logger to capture log messages
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:debug)

      # The service should not raise an error
      expect {
        result = AdminNotificationService.notify(:user_registered, user: user)
        expect(result).to be_nil
      }.not_to raise_error

      # Verify appropriate logging occurred
      expect(Rails.logger).to have_received(:warn)
        .with(/Redis unavailable during admin notification creation/)
      expect(Rails.logger).to have_received(:info)
        .with(/Critical operation can continue/)
    end

    it 'handles Redis connection failures during broadcast gracefully' do
      # Create a real notification
      notification = create(:admin_notification, user: user, event_type: 'user_registered')
      
      # Mock the notification creation to return our notification
      allow(AdminNotification).to receive(:notify_user_registered).and_return(notification)
      allow(notification).to receive(:persisted?).and_return(true)
      
      # Mock Turbo broadcast to fail with Redis error
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to)
        .and_raise(Redis::CannotConnectError.new('Connection refused'))
      
      # Mock logger
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:debug)

      # The service should not raise an error
      expect {
        result = AdminNotificationService.notify(:user_registered, user: user)
        expect(result).to eq(notification)
      }.not_to raise_error

      # Verify appropriate logging occurred
      expect(Rails.logger).to have_received(:warn)
        .with(/Redis unavailable for admin notification broadcast/)
      expect(Rails.logger).to have_received(:info)
        .with(/Admin notification created successfully, but real-time broadcast skipped/)
    end

    it 'handles Redis connection failures during duplicate check gracefully' do
      # Mock the duplicate check to fail with Redis error
      allow_any_instance_of(AdminNotificationService).to receive(:duplicate_notification_exists?)
        .and_raise(Redis::CannotConnectError.new('Connection refused'))
      
      # Mock logger
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:info)

      # Create a real notification for the service to return
      notification = create(:admin_notification, user: user, event_type: 'user_registered')
      allow(AdminNotification).to receive(:notify_user_registered).and_return(notification)

      # The service should still work
      expect {
        result = AdminNotificationService.notify(:user_registered, user: user)
        expect(result).to eq(notification)
      }.not_to raise_error

      # Verify appropriate logging occurred
      expect(Rails.logger).to have_received(:warn)
        .with(/Redis unavailable for notification validation/)
      expect(Rails.logger).to have_received(:info)
        .with(/Proceeding with notification due to Redis connectivity issues/)
    end

    it 'successfully creates notifications when Redis is available' do
      # Don't mock anything - let it work normally
      expect {
        result = AdminNotificationService.notify(:user_registered, user: user)
        expect(result).to be_present
        expect(result.event_type).to eq('user_registered')
        expect(result.user).to eq(user)
      }.to change(AdminNotification, :count).by(1)
    end
  end

  describe 'Superadmin creation resilience' do
    it 'completes user creation even when Redis notifications fail' do
      # Mock the notification service to fail with Redis error
      allow(AdminNotificationService).to receive(:notify)
        .and_raise(Redis::CannotConnectError.new('Connection refused'))

      # Create a user (which triggers the after_create callback)
      expect {
        user = User.create!(
          email: 'test@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          first_name: 'Test',
          last_name: 'User'
        )
        expect(user).to be_persisted
      }.to change(User, :count).by(1)
      
      # The user should be created successfully despite the Redis failure
      created_user = User.find_by(email: 'test@example.com')
      expect(created_user).to be_present
      expect(created_user.first_name).to eq('Test')
    end
  end
end