# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminMonitoringService, type: :service do
  let(:service) { described_class.new }
  let(:superadmin) { create(:user, role: 'superadmin') }
  let(:regular_user) { create(:user, role: 'user') }

  describe '#check_security_alerts' do
    it 'returns empty array when no security issues' do
      alerts = service.check_security_alerts
      expect(alerts).to be_an(Array)
      expect(alerts).to be_empty
    end

    it 'detects suspicious IP activity' do
      ip_address = '192.168.1.100'
      
      # Create multiple failed attempts from same IP
      6.times do
        create(:audit_log, :xss_attempt, ip_address: ip_address, created_at: 30.minutes.ago)
      end
      
      alerts = service.check_security_alerts
      
      expect(alerts).not_to be_empty
      suspicious_ip_alert = alerts.find { |alert| alert[:type] == 'suspicious_ip' }
      expect(suspicious_ip_alert).to be_present
      expect(suspicious_ip_alert[:ip_address]).to eq(ip_address)
      expect(suspicious_ip_alert[:count]).to eq(6)
      expect(suspicious_ip_alert[:severity]).to eq('medium')
    end

    it 'detects excessive admin activity' do
      # Create excessive admin actions for a user
      110.times do
        create(:audit_log, event_type: 'admin_action', user: superadmin, created_at: 30.minutes.ago)
      end
      
      alerts = service.check_security_alerts
      
      excessive_activity_alert = alerts.find { |alert| alert[:type] == 'excessive_admin_activity' }
      expect(excessive_activity_alert).to be_present
      expect(excessive_activity_alert[:user_id]).to eq(superadmin.id)
      expect(excessive_activity_alert[:count]).to eq(110)
    end

    it 'detects coordinated attacks' do
      ip_address = '192.168.1.200'
      
      # Create many failed login attempts from same IP
      15.times do
        create(:audit_log, :csrf_failure, ip_address: ip_address, created_at: 30.minutes.ago)
      end
      
      alerts = service.check_security_alerts
      
      coordinated_attack_alert = alerts.find { |alert| alert[:type] == 'coordinated_attack' }
      expect(coordinated_attack_alert).to be_present
      expect(coordinated_attack_alert[:ip_address]).to eq(ip_address)
      expect(coordinated_attack_alert[:severity]).to eq('high')
    end

    it 'detects session security issues' do
      # Create multiple session security events
      6.times do
        create(:audit_log, :suspicious_admin_activity, created_at: 12.hours.ago)
      end
      
      alerts = service.check_security_alerts
      
      session_alert = alerts.find { |alert| alert[:type] == 'session_security_issues' }
      expect(session_alert).to be_present
      expect(session_alert[:count]).to eq(6)
    end
  end

  describe '#security_dashboard_data' do
    before do
      # Create some test data
      create(:audit_log, :xss_attempt, created_at: 2.hours.ago)
      create(:audit_log, :sql_injection_attempt, created_at: 30.minutes.ago)
      create(:audit_log, event_type: 'admin_action', user: superadmin, created_at: 1.hour.ago)
    end

    it 'returns comprehensive dashboard data' do
      data = service.security_dashboard_data
      
      expect(data).to have_key(:security_alerts_today)
      expect(data).to have_key(:failed_attempts_last_hour)
      expect(data).to have_key(:top_suspicious_ips)
      expect(data).to have_key(:admin_activity_summary)
      expect(data).to have_key(:recent_security_events)
      
      expect(data[:security_alerts_today]).to be >= 0
      expect(data[:recent_security_events]).to be_an(Array)
    end
  end

  describe '#monitor_user_activity' do
    before do
      # Create admin activity for the user
      3.times do |i|
        create(:audit_log, event_type: 'admin_action', user: superadmin, created_at: i.days.ago)
      end
      
      create(:audit_log, :xss_attempt, user: superadmin, created_at: 1.day.ago)
    end

    it 'returns user activity summary' do
      activity = service.monitor_user_activity(superadmin.id, 7)
      
      expect(activity).to have_key(:total_actions)
      expect(activity).to have_key(:activity_by_day)
      expect(activity).to have_key(:security_events)
      expect(activity).to have_key(:last_activity)
      
      expect(activity[:total_actions]).to eq(3)
      expect(activity[:security_events]).to eq(1)
      expect(activity[:last_activity]).to be_present
    end

    it 'returns empty data for invalid user' do
      activity = service.monitor_user_activity(nil)
      expect(activity).to eq({})
    end
  end

  describe '#should_block_ip?' do
    let(:ip_address) { '192.168.1.300' }

    it 'returns false for clean IP' do
      expect(service.should_block_ip?(ip_address)).to be false
    end

    it 'returns true for suspicious IP' do
      # Create enough failed attempts to trigger blocking
      6.times do
        create(:audit_log, :sql_injection_attempt, ip_address: ip_address, created_at: 30.minutes.ago)
      end
      
      expect(service.should_block_ip?(ip_address)).to be true
    end

    it 'returns false for blank IP' do
      expect(service.should_block_ip?('')).to be false
      expect(service.should_block_ip?(nil)).to be false
    end
  end

  describe '#generate_security_report' do
    let(:start_date) { 7.days.ago }
    let(:end_date) { Time.current }

    before do
      # Create test data within the period
      create(:audit_log, :xss_attempt, ip_address: '192.168.1.1', created_at: 3.days.ago)
      create(:audit_log, :sql_injection_attempt, ip_address: '192.168.1.1', created_at: 2.days.ago)
      create(:audit_log, event_type: 'admin_action', user: superadmin, created_at: 1.day.ago)
      
      # Create data outside the period (should not be included)
      create(:audit_log, :csrf_failure, created_at: 10.days.ago)
    end

    it 'generates comprehensive security report' do
      report = service.generate_security_report(start_date, end_date)
      
      expect(report).to have_key(:period)
      expect(report).to have_key(:total_security_events)
      expect(report).to have_key(:security_events_by_type)
      expect(report).to have_key(:top_targeted_ips)
      expect(report).to have_key(:admin_activity_summary)
      expect(report).to have_key(:recommendations)
      
      expect(report[:total_security_events]).to eq(2) # Only events within period
      expect(report[:security_events_by_type]).to have_key('xss_attempt')
      expect(report[:security_events_by_type]).to have_key('sql_injection_attempt')
      expect(report[:recommendations]).to be_an(Array)
      expect(report[:recommendations]).not_to be_empty
    end

    it 'includes period information in report' do
      report = service.generate_security_report(start_date, end_date)
      
      expect(report[:period]).to include(start_date.strftime('%Y-%m-%d'))
      expect(report[:period]).to include(end_date.strftime('%Y-%m-%d'))
    end
  end

  describe 'private methods' do
    describe 'security recommendations' do
      it 'provides default recommendation when no issues detected' do
        report = service.generate_security_report
        
        expect(report[:recommendations]).to include('Regularly review and rotate admin credentials')
      end

      it 'recommends IP blocking for high-risk IPs' do
        ip_address = '192.168.1.400'
        
        # Create many failed attempts to trigger high-risk status
        25.times do
          create(:audit_log, :xss_attempt, ip_address: ip_address, created_at: 2.days.ago)
        end
        
        report = service.generate_security_report
        
        expect(report[:recommendations]).to include('Consider implementing IP blocking for addresses with excessive failed attempts')
      end

      it 'recommends admin review for high activity' do
        # Create high admin activity
        1100.times do
          create(:audit_log, event_type: 'admin_action', user: superadmin, created_at: 3.days.ago)
        end
        
        report = service.generate_security_report
        
        expect(report[:recommendations]).to include('High admin activity detected - review admin access logs for unusual patterns')
      end

      it 'recommends investigation for security event spikes' do
        # Create security events in last 24 hours
        10.times do
          create(:audit_log, :xss_attempt, created_at: 12.hours.ago)
        end
        
        # Create fewer events in previous 24 hours
        3.times do
          create(:audit_log, :sql_injection_attempt, created_at: 36.hours.ago)
        end
        
        report = service.generate_security_report
        
        expect(report[:recommendations]).to include('Security events have doubled in the last 24 hours - investigate potential threats')
      end
    end
  end
end