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

  describe 'Redis error handling' do
    before { allow(Rails.env).to receive(:test?).and_return(false) }

    describe 'notification creation with Redis failures' do
      before { allow(Rails.env).to receive(:test?).and_return(false) }

      it 'handles Redis connection errors during notification creation' do
        allow(AdminNotification).to receive(:notify_user_registered)
          .and_raise(Redis::CannotConnectError.new('Connection refused'))
        allow(Rails.logger).to receive(:warn)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:debug)

        result = AdminNotificationService.notify(:user_registered, user: user)

        expect(result).to be_nil
        expect(Rails.logger).to have_received(:warn)
          .with(/Redis unavailable during admin notification creation/)
        expect(Rails.logger).to have_received(:info)
          .with(/Critical operation can continue/)
      end

      it 'handles Redis timeout errors during notification creation' do
        allow(AdminNotification).to receive(:notify_user_registered)
          .and_raise(Redis::TimeoutError.new('Timeout'))
        allow(Rails.logger).to receive(:warn)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:debug)

        expect {
          AdminNotificationService.notify(:user_registered, user: user)
        }.not_to raise_error

        expect(Rails.logger).to have_received(:warn)
          .with(/Redis unavailable during admin notification creation/)
      end
    end

    describe 'broadcast with Redis failures' do
      let(:notification) { create(:admin_notification, user: user) }

      before do
        allow(Rails.env).to receive(:test?).and_return(false)
        allow(AdminNotification).to receive(:notify_user_registered).and_return(notification)
        allow(notification).to receive(:persisted?).and_return(true)
        allow(AdminNotification).to receive(:unread).and_return(double(count: 5))
      end

      it 'handles Redis connection errors during broadcast' do
        allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to)
          .and_raise(Redis::CannotConnectError.new('Connection refused'))
        allow(Rails.logger).to receive(:warn)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:debug)

        expect {
          AdminNotificationService.notify(:user_registered, user: user)
        }.not_to raise_error

        expect(Rails.logger).to have_received(:warn)
          .with(/Redis unavailable for admin notification broadcast/)
        expect(Rails.logger).to have_received(:info)
          .with(/Admin notification created successfully, but real-time broadcast skipped/)
      end

      it 'handles Redis timeout errors during broadcast' do
        allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to)
          .and_raise(Redis::TimeoutError.new('Timeout'))
        allow(Rails.logger).to receive(:warn)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:debug)

        expect {
          AdminNotificationService.notify(:user_registered, user: user)
        }.not_to raise_error

        expect(Rails.logger).to have_received(:warn)
          .with(/Redis unavailable for admin notification broadcast/)
      end

      it 'handles Redis connection errors during counter update' do
        allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to)
        allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
          .and_raise(Redis::ConnectionError.new('Connection lost'))
        allow(Rails.logger).to receive(:warn)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:debug)

        expect {
          AdminNotificationService.notify(:user_registered, user: user)
        }.not_to raise_error

        expect(Rails.logger).to have_received(:warn)
          .with(/Redis unavailable for admin notification broadcast/)
      end

      it 'identifies Redis-related errors correctly' do
        service = AdminNotificationService.new(:user_registered, user: user)
        
        redis_error = StandardError.new('Redis connection failed')
        connection_error = StandardError.new('Connection timeout occurred')
        other_error = StandardError.new('Some other error')

        expect(service.send(:redis_related_error?, redis_error)).to be true
        expect(service.send(:redis_related_error?, connection_error)).to be true
        expect(service.send(:redis_related_error?, other_error)).to be false
      end
    end

    describe 'duplicate notification check with Redis failures' do
      it 'handles Redis errors during duplicate check gracefully' do
        allow(AdminNotification).to receive(:where)
          .and_raise(Redis::CannotConnectError.new('Connection refused'))
        allow(AdminNotification).to receive(:notify_user_registered) do
          create(:admin_notification, user: user, event_type: 'user_registered')
        end
        allow(Rails.logger).to receive(:warn)
        allow(Rails.logger).to receive(:info)

        # Should still create notification when Redis is unavailable
        result = AdminNotificationService.notify(:user_registered, user: user, force_in_test: true)

        expect(result).to be_present
        expect(Rails.logger).to have_received(:warn)
          .with(/Redis unavailable for notification validation/)
        expect(Rails.logger).to have_received(:info)
          .with(/Proceeding with notification due to Redis connectivity issues/)
      end
    end

    describe 'Sentry integration' do
      before do
        allow(Rails.env).to receive(:test?).and_return(false)
        stub_const('Sentry', double('Sentry'))
        allow(Sentry).to receive(:capture_exception)
      end

      it 'sends Redis errors to Sentry during notification creation' do
        error = Redis::CannotConnectError.new('Connection refused')
        allow(AdminNotification).to receive(:notify_user_registered).and_raise(error)
        allow(Rails.logger).to receive(:warn)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:debug)

        AdminNotificationService.notify(:user_registered, user: user)

        expect(Sentry).to have_received(:capture_exception).with(
          error,
          extra: hash_including(
            context: 'admin_notification_redis_failure',
            event_type: :user_registered,
            user_id: user.id
          )
        )
      end

      it 'sends Redis errors to Sentry during broadcast' do
        notification = create(:admin_notification, user: user)
        allow(AdminNotification).to receive(:notify_user_registered).and_return(notification)
        allow(notification).to receive(:persisted?).and_return(true)
        allow(AdminNotification).to receive(:unread).and_return(double(count: 5))

        error = Redis::CannotConnectError.new('Connection refused')
        allow(Turbo::StreamsChannel).to receive(:broadcast_prepend_to).and_raise(error)
        allow(Rails.logger).to receive(:warn)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:debug)

        AdminNotificationService.notify(:user_registered, user: user)

        expect(Sentry).to have_received(:capture_exception).with(
          error,
          extra: hash_including(
            context: 'admin_notification_broadcast',
            user_id: user.id
          )
        )
      end
    end
  end
end