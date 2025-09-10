# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminSecurityMonitoringJob, type: :job do
  let(:job) { described_class.new }
  let(:superadmin) { create(:user, role: 'superadmin') }

  describe '#perform' do
    it 'completes without errors when no alerts' do
      expect { job.perform }.not_to raise_error
    end

    it 'processes security alerts' do
      # Create conditions that will generate alerts
      ip_address = '192.168.1.100'
      6.times do
        create(:audit_log, :xss_attempt, ip_address: ip_address, created_at: 30.minutes.ago)
      end

      expect {
        job.perform
      }.to change(AuditLog.where(event_type: 'security_alert_generated'), :count).by_at_least(1)
    end

    it 'cleans up old audit logs' do
      # Create old audit logs
      old_logs = []
      5.times do
        old_logs << create(:audit_log, event_type: 'admin_action', created_at: 100.days.ago)
      end
      
      # Create recent logs (should not be deleted)
      recent_log = create(:audit_log, event_type: 'admin_action', created_at: 1.day.ago)

      expect {
        job.perform
      }.to change(AuditLog, :count).by(-5) # 5 old logs deleted, but new cleanup log created

      # Verify old logs are gone
      old_logs.each do |log|
        expect(AuditLog.exists?(log.id)).to be false
      end
      
      # Verify recent log remains
      expect(AuditLog.exists?(recent_log.id)).to be true
    end

    it 'logs cleanup activity' do
      # Create old audit logs to trigger cleanup
      3.times do
        create(:audit_log, event_type: 'admin_action', created_at: 100.days.ago)
      end

      expect {
        job.perform
      }.to change(AuditLog.where(event_type: 'audit_log_cleanup'), :count).by(1)

      cleanup_log = AuditLog.where(event_type: 'audit_log_cleanup').last
      expect(cleanup_log.details['deleted_count']).to eq(3)
    end
  end

  describe 'alert processing' do
    let(:monitoring_service) { instance_double(AdminMonitoringService) }

    before do
      allow(AdminMonitoringService).to receive(:new).and_return(monitoring_service)
      allow(monitoring_service).to receive(:check_security_alerts).and_return([])
    end

    describe '#process_alert' do
      it 'handles high severity alerts' do
        alert = {
          type: 'coordinated_attack',
          severity: 'high',
          message: 'Test high severity alert',
          ip_address: '192.168.1.1'
        }

        expect(Rails.logger).to receive(:error).with(/HIGH SEVERITY SECURITY ALERT/)
        
        expect {
          job.send(:process_alert, alert)
        }.to change(AuditLog.where(event_type: 'security_alert_generated'), :count).by(1)
      end

      it 'handles medium severity alerts' do
        alert = {
          type: 'excessive_admin_activity',
          severity: 'medium',
          message: 'Test medium severity alert'
        }

        expect(Rails.logger).to receive(:warn).with(/MEDIUM SEVERITY SECURITY ALERT/)
        
        job.send(:process_alert, alert)
      end

      it 'handles low severity alerts' do
        alert = {
          type: 'minor_issue',
          severity: 'low',
          message: 'Test low severity alert'
        }

        expect(Rails.logger).to receive(:info).with(/LOW SEVERITY SECURITY ALERT/)
        
        job.send(:process_alert, alert)
      end
    end

    describe '#notify_superadmins' do
      before do
        create(:user, role: 'superadmin', email: 'admin1@example.com')
        create(:user, role: 'superadmin', email: 'admin2@example.com')
        create(:user, role: 'user', email: 'user@example.com') # Should not be notified
      end

      it 'creates notification logs for all superadmins' do
        alert = {
          type: 'test_alert',
          message: 'Test alert message',
          severity: 'high'
        }

        expect {
          job.send(:notify_superadmins, alert)
        }.to change(AuditLog.where(event_type: 'security_alert_notification'), :count).by(2)

        # Verify notifications were created for superadmins only
        notifications = AuditLog.where(event_type: 'security_alert_notification')
        notification_users = notifications.map(&:user)
        
        expect(notification_users.all?(&:superadmin?)).to be true
        expect(notification_users.count).to eq(2)
      end
    end

    describe '#consider_ip_blocking' do
      it 'logs IP block recommendation' do
        ip_address = '192.168.1.200'

        expect(Rails.logger).to receive(:error).with(/CONSIDERING IP BLOCK/)
        
        expect {
          job.send(:consider_ip_blocking, ip_address)
        }.to change(AuditLog.where(event_type: 'ip_block_recommendation'), :count).by(1)

        block_log = AuditLog.where(event_type: 'ip_block_recommendation').last
        expect(block_log.details['ip_address']).to eq(ip_address)
        expect(block_log.details['reason']).to eq('coordinated_attack')
      end

      it 'handles blank IP addresses gracefully' do
        expect {
          job.send(:consider_ip_blocking, '')
          job.send(:consider_ip_blocking, nil)
        }.not_to change(AuditLog, :count)
      end
    end

    describe '#business_hours?' do
      it 'returns true during business hours' do
        # Monday 10 AM UTC
        travel_to Time.utc(2024, 1, 8, 10, 0, 0) do
          expect(job.send(:business_hours?)).to be true
        end
      end

      it 'returns false outside business hours' do
        # Saturday 10 AM UTC
        travel_to Time.utc(2024, 1, 6, 10, 0, 0) do
          expect(job.send(:business_hours?)).to be false
        end
        
        # Monday 6 AM UTC (before business hours)
        travel_to Time.utc(2024, 1, 8, 6, 0, 0) do
          expect(job.send(:business_hours?)).to be false
        end
        
        # Monday 8 PM UTC (after business hours)
        travel_to Time.utc(2024, 1, 8, 20, 0, 0) do
          expect(job.send(:business_hours?)).to be false
        end
      end
    end
  end

  describe 'integration with monitoring service' do
    it 'uses real monitoring service to check alerts' do
      # Create conditions for alerts
      ip_address = '192.168.1.300'
      10.times do
        create(:audit_log, :csrf_failure, ip_address: ip_address, created_at: 30.minutes.ago)
      end

      expect {
        job.perform
      }.to change(AuditLog.where(event_type: 'security_alert_generated'), :count).by_at_least(1)

      # Verify the alert contains expected information
      alert_log = AuditLog.where(event_type: 'security_alert_generated').last
      expect(alert_log.details['type']).to eq('coordinated_attack')
      expect(alert_log.details['ip_address']).to eq(ip_address)
    end
  end
end