require 'rails_helper'

RSpec.describe 'Redis SSL Error Handling Integration', type: :integration do
  describe 'AdminNotificationService Redis resilience' do
    let(:user) { create(:user) }

    before do
      # Ensure we're not in test mode for these tests
      allow(Rails.env).to receive(:test?).and_return(false)
    end

    it 'handles Redis connection failures during notification creation' do
      # Mock AdminNotification to raise Redis error
      allow(AdminNotification).to receive(:notify_user_registered)
        .and_raise(Redis::CannotConnectError.new('Connection refused'))
      
      # Mock logger to capture log messages
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:debug)

      # The service should not raise an error and should return nil
      result = AdminNotificationService.notify(:user_registered, user: user)
      expect(result).to be_nil

      # Verify appropriate logging occurred
      expect(Rails.logger).to have_received(:warn)
        .with(/Redis unavailable during admin notification creation/)
      expect(Rails.logger).to have_received(:info)
        .with(/Critical operation can continue/)
    end

    it 'handles Redis connection failures during broadcast' do
      # Create a real notification
      notification = create(:admin_notification, user: user, event_type: 'user_registered')
      
      # Mock the notification creation to return our notification
      allow(AdminNotification).to receive(:notify_user_registered).and_return(notification)
      allow(notification).to receive(:persisted?).and_return(true)
      allow(AdminNotification).to receive(:unread).and_return(double(count: 5))
      
      # Mock Turbo broadcast to fail with Redis error
      allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to)
        .and_raise(Redis::CannotConnectError.new('Connection refused'))
      
      # Mock logger
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:debug)

      # The service should not raise an error and should return the notification
      result = AdminNotificationService.notify(:user_registered, user: user)
      expect(result).to eq(notification)

      # Verify appropriate logging occurred
      expect(Rails.logger).to have_received(:warn)
        .with(/Redis unavailable for admin notification broadcast/)
      expect(Rails.logger).to have_received(:info)
        .with(/Admin notification created successfully, but real-time broadcast skipped/)
    end
  end

  describe 'User model Redis resilience' do
    it 'completes user creation even when admin notification fails with Redis error' do
      # Mock the AdminNotificationService to fail with Redis error
      allow(AdminNotificationService).to receive(:notify)
        .and_raise(Redis::CannotConnectError.new('Connection refused'))
      
      # Mock logger
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:info)

      # Create a user (which triggers the after_create callback)
      expect {
        user = User.create!(
          email: 'redis-test@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          first_name: 'Redis',
          last_name: 'Test'
        )
        expect(user).to be_persisted
      }.to change(User, :count).by(1)
      
      # Verify appropriate logging occurred
      expect(Rails.logger).to have_received(:warn)
        .with(/Redis unavailable during user registration notification/)
      expect(Rails.logger).to have_received(:info)
        .with(/User registration completed successfully, but admin notification skipped/)
    end

    it 'completes subscription changes even when admin notification fails with Redis error' do
      user = create(:user, subscription_tier: 'basic')
      
      # Mock the AdminNotificationService to fail with Redis error
      allow(AdminNotificationService).to receive(:notify)
        .and_raise(Redis::CannotConnectError.new('Connection refused'))
      
      # Mock logger
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:info)

      # Update user subscription (which triggers the after_update callback)
      expect {
        user.update!(subscription_tier: 'premium')
        expect(user.reload.subscription_tier).to eq('premium')
      }.not_to raise_error
      
      # Verify appropriate logging occurred
      expect(Rails.logger).to have_received(:warn)
        .with(/Redis unavailable during subscription change notification/)
      expect(Rails.logger).to have_received(:info)
        .with(/Subscription change completed successfully, but admin notification skipped/)
    end
  end

  describe 'Superadmin creation task Redis resilience' do
    it 'creates superadmin successfully even when Redis is unavailable' do
      # This test verifies that the rake task error handling works
      # We'll simulate this by creating a superadmin user directly
      
      # Mock the AdminNotificationService to fail with Redis error
      allow(AdminNotificationService).to receive(:notify)
        .and_raise(Redis::CannotConnectError.new('Connection refused'))
      
      # Mock logger
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:info)

      # Create a superadmin user (simulating what the rake task does)
      expect {
        superadmin = User.create!(
          email: 'superadmin-redis-test@example.com',
          password: 'SuperPassword123!',
          password_confirmation: 'SuperPassword123!',
          first_name: 'Super',
          last_name: 'Admin',
          role: 'superadmin',
          subscription_tier: 'premium'
        )
        expect(superadmin).to be_persisted
        expect(superadmin.role).to eq('superadmin')
      }.to change(User, :count).by(1)
      
      # Verify appropriate logging occurred
      expect(Rails.logger).to have_received(:warn)
        .with(/Redis unavailable during user registration notification/)
      expect(Rails.logger).to have_received(:info)
        .with(/User registration completed successfully, but admin notification skipped/)
    end
  end

  describe 'Error identification' do
    it 'correctly identifies Redis-related errors' do
      service = AdminNotificationService.new(:user_registered, user: create(:user))
      
      redis_error = StandardError.new('Redis connection failed')
      connection_error = StandardError.new('Connection timeout occurred')
      other_error = StandardError.new('Some other error')

      expect(service.send(:redis_related_error?, redis_error)).to be true
      expect(service.send(:redis_related_error?, connection_error)).to be true
      expect(service.send(:redis_related_error?, other_error)).to be false
    end
  end
end