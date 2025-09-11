# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'Superadmin Creation with Redis SSL', type: :integration do
  before(:all) do
    Rails.application.load_tasks
  end

  let(:task) { Rake::Task['create_superadmin'] }
  
  before do
    task.reenable
    allow($stdout).to receive(:write)
    allow($stdin).to receive(:gets).and_return("admin@example.com\n", "password123\n", "password123\n")
  end

  describe 'superadmin creation with Redis SSL available' do
    context 'when Redis SSL connection is working' do
      before do
        # Ensure Redis is available for this test
        allow_any_instance_of(Redis).to receive(:ping).and_return('PONG')
      end

      it 'creates superadmin and sends notifications successfully' do
        expect {
          task.invoke
        }.to change(User, :count).by(1)
        
        created_user = User.last
        expect(created_user.email).to eq('admin@example.com')
        expect(created_user.admin?).to be true
      end

      it 'handles notification sending with SSL Redis' do
        allow(AdminNotificationService).to receive(:new).and_return(
          instance_double(AdminNotificationService, notify_admin_of_user_registration: true)
        )
        
        expect {
          task.invoke
        }.not_to raise_error
        
        expect(AdminNotificationService).to have_received(:new)
      end
    end
  end

  describe 'superadmin creation with Redis SSL failures' do
    context 'when Redis SSL connection fails' do
      before do
        # Mock Redis SSL connection failure
        allow_any_instance_of(Redis).to receive(:ping).and_raise(
          OpenSSL::SSL::SSLError.new('certificate verify failed (self-signed certificate in certificate chain)')
        )
        allow_any_instance_of(Redis).to receive(:publish).and_raise(
          OpenSSL::SSL::SSLError.new('SSL handshake failed')
        )
        allow(Rails.logger).to receive(:warn)
        allow(Rails.logger).to receive(:info)
      end

      it 'creates superadmin successfully despite Redis SSL failures' do
        expect {
          task.invoke
        }.to change(User, :count).by(1)
        
        created_user = User.last
        expect(created_user.email).to eq('admin@example.com')
        expect(created_user.admin?).to be true
      end

      it 'logs appropriate warnings when Redis SSL fails' do
        task.invoke
        
        expect(Rails.logger).to have_received(:warn).with(/Redis unavailable/)
        expect(Rails.logger).to have_received(:info).with(/Superadmin created successfully/)
      end

      it 'handles notification failures gracefully' do
        # Mock the notification service to simulate Redis failure
        notification_service = instance_double(AdminNotificationService)
        allow(AdminNotificationService).to receive(:new).and_return(notification_service)
        allow(notification_service).to receive(:notify_admin_of_user_registration).and_raise(
          Redis::CannotConnectError.new('SSL connection failed')
        )
        
        expect {
          task.invoke
        }.not_to raise_error
        
        # User should still be created
        expect(User.count).to be > 0
      end
    end

    context 'when Redis connection times out with SSL' do
      before do
        allow_any_instance_of(Redis).to receive(:ping).and_raise(
          Redis::TimeoutError.new('Timed out connecting to Redis on rediss://host:6380')
        )
        allow(Rails.logger).to receive(:warn)
        allow(Rails.logger).to receive(:info)
      end

      it 'creates superadmin successfully despite Redis timeout' do
        expect {
          task.invoke
        }.to change(User, :count).by(1)
        
        created_user = User.last
        expect(created_user.admin?).to be true
      end

      it 'logs timeout warnings appropriately' do
        task.invoke
        
        expect(Rails.logger).to have_received(:warn).with(/Redis unavailable/)
      end
    end

    context 'when Redis is completely unavailable' do
      before do
        allow_any_instance_of(Redis).to receive(:ping).and_raise(
          Redis::CannotConnectError.new('Connection refused - connect(2) for 127.0.0.1:6379')
        )
        allow(Rails.logger).to receive(:warn)
        allow(Rails.logger).to receive(:info)
      end

      it 'creates superadmin successfully without Redis' do
        expect {
          task.invoke
        }.to change(User, :count).by(1)
        
        created_user = User.last
        expect(created_user.admin?).to be true
      end

      it 'completes task execution without errors' do
        expect {
          task.invoke
        }.not_to raise_error
      end
    end
  end

  describe 'superadmin creation error recovery' do
    context 'when Redis becomes available during task execution' do
      it 'adapts to Redis availability changes' do
        # Start with Redis unavailable
        allow_any_instance_of(Redis).to receive(:ping).and_raise(
          Redis::CannotConnectError.new('Connection refused')
        )
        
        # Mock notification service to simulate Redis becoming available
        notification_service = instance_double(AdminNotificationService)
        allow(AdminNotificationService).to receive(:new).and_return(notification_service)
        
        # First call fails, second succeeds
        allow(notification_service).to receive(:notify_admin_of_user_registration)
          .and_raise(Redis::CannotConnectError.new('Connection refused'))
          .and_return(true)
        
        expect {
          task.invoke
        }.not_to raise_error
        
        # User should be created regardless
        expect(User.count).to be > 0
      end
    end
  end

  describe 'superadmin creation with different SSL scenarios' do
    context 'with self-signed certificate errors' do
      before do
        allow_any_instance_of(Redis).to receive(:ping).and_raise(
          OpenSSL::SSL::SSLError.new('certificate verify failed (self-signed certificate in certificate chain)')
        )
        allow(Rails.logger).to receive(:warn)
      end

      it 'handles self-signed certificate errors gracefully' do
        expect {
          task.invoke
        }.to change(User, :count).by(1)
        
        expect(Rails.logger).to have_received(:warn).with(/Redis unavailable/)
      end
    end

    context 'with SSL protocol errors' do
      before do
        allow_any_instance_of(Redis).to receive(:ping).and_raise(
          OpenSSL::SSL::SSLError.new('wrong version number')
        )
        allow(Rails.logger).to receive(:warn)
      end

      it 'handles SSL protocol errors gracefully' do
        expect {
          task.invoke
        }.to change(User, :count).by(1)
        
        expect(Rails.logger).to have_received(:warn).with(/Redis unavailable/)
      end
    end
  end

  describe 'superadmin creation performance with Redis SSL' do
    it 'completes within reasonable time even with Redis failures' do
      allow_any_instance_of(Redis).to receive(:ping).and_raise(
        Redis::TimeoutError.new('Timeout')
      )
      allow(Rails.logger).to receive(:warn)
      
      start_time = Time.current
      task.invoke
      end_time = Time.current
      
      duration = end_time - start_time
      expect(duration).to be < 10.seconds # Should complete quickly even with timeouts
    end
  end

  describe 'superadmin creation data integrity with Redis SSL failures' do
    it 'maintains database consistency when Redis fails' do
      allow_any_instance_of(Redis).to receive(:ping).and_raise(
        OpenSSL::SSL::SSLError.new('SSL error')
      )
      allow(Rails.logger).to receive(:warn)
      
      initial_count = User.count
      
      task.invoke
      
      # Database should be consistent
      expect(User.count).to eq(initial_count + 1)
      
      created_user = User.last
      expect(created_user).to be_valid
      expect(created_user).to be_persisted
      expect(created_user.admin?).to be true
    end

    it 'does not leave partial records when Redis fails' do
      # Mock a scenario where user creation succeeds but notification fails
      allow_any_instance_of(Redis).to receive(:ping).and_return('PONG')
      allow_any_instance_of(Redis).to receive(:publish).and_raise(
        OpenSSL::SSL::SSLError.new('SSL error during notification')
      )
      allow(Rails.logger).to receive(:warn)
      
      expect {
        task.invoke
      }.to change(User, :count).by(1)
      
      # User should be fully created and valid
      created_user = User.last
      expect(created_user).to be_valid
      expect(created_user.admin?).to be true
    end
  end
end