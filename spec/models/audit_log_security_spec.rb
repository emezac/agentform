# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuditLog, type: :model do
  let(:user) { create(:user) }
  let(:superadmin) { create(:user, role: 'superadmin') }

  describe 'security event tracking' do
    it 'identifies security events correctly' do
      security_log = create(:audit_log, event_type: 'sql_injection_attempt', user: user)
      normal_log = create(:audit_log, event_type: 'admin_action', user: user)
      
      expect(security_log.security_event?).to be true
      expect(normal_log.security_event?).to be false
    end

    it 'identifies admin actions correctly' do
      admin_log = create(:audit_log, event_type: 'admin_action', user: superadmin)
      security_log = create(:audit_log, event_type: 'xss_attempt', user: user)
      
      expect(admin_log.admin_action?).to be true
      expect(security_log.admin_action?).to be false
    end

    it 'identifies failed security attempts correctly' do
      sql_log = create(:audit_log, event_type: 'sql_injection_attempt', user: user)
      xss_log = create(:audit_log, event_type: 'xss_attempt', user: user)
      csrf_log = create(:audit_log, event_type: 'csrf_failure', user: user)
      normal_log = create(:audit_log, event_type: 'admin_action', user: user)
      
      expect(sql_log.failed_security_attempt?).to be true
      expect(xss_log.failed_security_attempt?).to be true
      expect(csrf_log.failed_security_attempt?).to be true
      expect(normal_log.failed_security_attempt?).to be false
    end
  end

  describe 'scopes' do
    before do
      create(:audit_log, event_type: 'admin_action', user: superadmin)
      create(:audit_log, event_type: 'sql_injection_attempt', user: user, ip_address: '192.168.1.1')
      create(:audit_log, event_type: 'xss_attempt', user: user, ip_address: '192.168.1.2')
      create(:audit_log, event_type: 'csrf_failure', user: user, ip_address: '192.168.1.1')
      create(:audit_log, event_type: 'user_login', user: user)
    end

    it 'filters security events' do
      expect(AuditLog.security_events.count).to eq(3)
    end

    it 'filters admin actions' do
      expect(AuditLog.admin_actions.count).to eq(1)
    end

    it 'filters failed attempts' do
      expect(AuditLog.failed_attempts.count).to eq(3)
    end

    it 'filters by IP address' do
      expect(AuditLog.by_ip('192.168.1.1').count).to eq(2)
    end

    it 'filters by user' do
      expect(AuditLog.for_user(user.id).count).to eq(4)
    end

    it 'filters today\'s events' do
      # Create an old event
      create(:audit_log, event_type: 'admin_action', user: user, created_at: 2.days.ago)
      
      expect(AuditLog.today.count).to eq(5) # All events created in before block are today
    end
  end

  describe 'class methods for security monitoring' do
    let(:ip_address) { '192.168.1.100' }
    
    before do
      # Create suspicious activity for IP
      create(:audit_log, event_type: 'sql_injection_attempt', ip_address: ip_address, created_at: 1.hour.ago)
      create(:audit_log, event_type: 'xss_attempt', ip_address: ip_address, created_at: 30.minutes.ago)
      create(:audit_log, event_type: 'csrf_failure', ip_address: ip_address, created_at: 10.minutes.ago)
      
      # Create old activity (should not count)
      create(:audit_log, event_type: 'sql_injection_attempt', ip_address: ip_address, created_at: 25.hours.ago)
      
      # Create activity for different IP
      create(:audit_log, event_type: 'xss_attempt', ip_address: '192.168.1.200', created_at: 1.hour.ago)
    end

    describe '.suspicious_activity_for_ip' do
      it 'counts suspicious activity for specific IP in last 24 hours' do
        count = AuditLog.suspicious_activity_for_ip(ip_address)
        expect(count).to eq(3)
      end

      it 'respects custom time window' do
        count = AuditLog.suspicious_activity_for_ip(ip_address, 2)
        expect(count).to eq(2) # Only events in last 2 hours
      end

      it 'returns 0 for clean IP' do
        count = AuditLog.suspicious_activity_for_ip('192.168.1.999')
        expect(count).to eq(0)
      end
    end

    describe '.admin_activity_summary' do
      before do
        create(:audit_log, event_type: 'admin_action', user: superadmin, created_at: 1.day.ago)
        create(:audit_log, event_type: 'admin_action', user: superadmin, created_at: 2.days.ago)
        create(:audit_log, event_type: 'admin_action', user: superadmin, created_at: 8.days.ago) # Should not count
      end

      it 'summarizes admin activity for user in specified days' do
        summary = AuditLog.admin_activity_summary(superadmin.id, 7)
        expect(summary['admin_action']).to eq(2)
      end

      it 'respects custom time window' do
        summary = AuditLog.admin_activity_summary(superadmin.id, 1)
        expect(summary['admin_action']).to eq(1)
      end
    end

    describe '.security_alerts_today' do
      before do
        create(:audit_log, event_type: 'sql_injection_attempt', created_at: Time.current)
        create(:audit_log, event_type: 'xss_attempt', created_at: Time.current)
        create(:audit_log, event_type: 'admin_action', created_at: Time.current) # Not a security event
        create(:audit_log, event_type: 'csrf_failure', created_at: 1.day.ago) # Not today
      end

      it 'counts security events for today only' do
        expect(AuditLog.security_alerts_today).to eq(2)
      end
    end

    describe '.top_suspicious_ips' do
      before do
        # IP with 3 failed attempts
        3.times { create(:audit_log, event_type: 'sql_injection_attempt', ip_address: '192.168.1.1') }
        
        # IP with 2 failed attempts
        2.times { create(:audit_log, event_type: 'xss_attempt', ip_address: '192.168.1.2') }
        
        # IP with 1 failed attempt
        create(:audit_log, event_type: 'csrf_failure', ip_address: '192.168.1.3')
        
        # Old attempts (should not count)
        create(:audit_log, event_type: 'sql_injection_attempt', ip_address: '192.168.1.4', created_at: 25.hours.ago)
      end

      it 'returns top suspicious IPs by failed attempt count' do
        top_ips = AuditLog.top_suspicious_ips(5)
        
        expect(top_ips['192.168.1.1']).to eq(3)
        expect(top_ips['192.168.1.2']).to eq(2)
        expect(top_ips['192.168.1.3']).to eq(1)
        expect(top_ips).not_to have_key('192.168.1.4')
      end

      it 'respects limit parameter' do
        top_ips = AuditLog.top_suspicious_ips(2)
        expect(top_ips.keys.length).to eq(2)
      end
    end
  end

  describe 'validations' do
    it 'validates event_type presence' do
      audit_log = build(:audit_log, event_type: nil)
      expect(audit_log).not_to be_valid
      expect(audit_log.errors[:event_type]).to include("can't be blank")
    end

    it 'validates IP address format for IPv4' do
      audit_log = build(:audit_log, ip_address: '192.168.1.1')
      expect(audit_log).to be_valid
    end

    it 'validates IP address format for IPv6' do
      audit_log = build(:audit_log, ip_address: '2001:0db8:85a3:0000:0000:8a2e:0370:7334')
      expect(audit_log).to be_valid
    end

    it 'rejects invalid IP address format' do
      audit_log = build(:audit_log, ip_address: 'invalid.ip.address')
      expect(audit_log).not_to be_valid
      expect(audit_log.errors[:ip_address]).to be_present
    end

    it 'allows blank IP address' do
      audit_log = build(:audit_log, ip_address: '')
      expect(audit_log).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to user optionally' do
      audit_log = create(:audit_log, user: nil)
      expect(audit_log).to be_valid
      expect(audit_log.user).to be_nil
    end

    it 'can be associated with a user' do
      audit_log = create(:audit_log, user: user)
      expect(audit_log.user).to eq(user)
    end
  end
end