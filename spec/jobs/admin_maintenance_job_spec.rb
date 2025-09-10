# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminMaintenanceJob, type: :job do
  let(:superadmin) { create(:user, role: 'superadmin') }
  
  before do
    # Create test data
    create_list(:user, 5)
    create_list(:discount_code, 3, created_by: superadmin)
    create_list(:audit_log, 10, user: superadmin)
    
    # Create some old audit logs
    create_list(:audit_log, 5, user: superadmin, created_at: 8.months.ago)
  end

  describe '#perform' do
    it 'runs full maintenance by default' do
      expect(DiscountCodeCleanupJob).to receive(:perform_now).and_return({})
      expect(AdminCacheService).to receive(:clear_all_caches).and_return(5)
      expect(AdminCacheService).to receive(:warm_up_caches)
      
      result = described_class.perform_now('full')
      
      expect(result).to be_a(Hash)
      expect(result[:task_type]).to eq('full')
      expect(result[:completed_tasks]).to be_an(Array)
      expect(result[:completed_tasks].length).to be >= 3
    end

    it 'runs cleanup only when specified' do
      expect(DiscountCodeCleanupJob).to receive(:perform_now).and_return({})
      expect(AdminCacheService).not_to receive(:clear_all_caches)
      
      result = described_class.perform_now('cleanup')
      
      expect(result[:task_type]).to eq('cleanup')
      expect(result[:completed_tasks].length).to eq(2) # cleanup + audit log cleanup
    end

    it 'runs cache warmup only when specified' do
      expect(DiscountCodeCleanupJob).not_to receive(:perform_now)
      expect(AdminCacheService).to receive(:clear_all_caches).and_return(3)
      expect(AdminCacheService).to receive(:warm_up_caches)
      
      result = described_class.perform_now('cache_warmup')
      
      expect(result[:task_type]).to eq('cache_warmup')
      expect(result[:completed_tasks].length).to eq(1)
    end

    it 'raises error for unknown task type' do
      expect {
        described_class.perform_now('unknown')
      }.to raise_error(ArgumentError, 'Unknown maintenance task type: unknown')
    end

    it 'logs successful maintenance completion' do
      allow(DiscountCodeCleanupJob).to receive(:perform_now).and_return({})
      allow(AdminCacheService).to receive(:clear_all_caches).and_return(5)
      allow(AdminCacheService).to receive(:warm_up_caches)
      
      expect {
        described_class.perform_now('full')
      }.to change(AuditLog, :count).by(1)
      
      audit_log = AuditLog.last
      expect(audit_log.event_type).to eq('admin_maintenance_completed')
      expect(audit_log.details['task_type']).to eq('full')
    end

    it 'logs maintenance failures' do
      allow(DiscountCodeCleanupJob).to receive(:perform_now).and_raise(StandardError, 'Test error')
      
      expect {
        described_class.perform_now('full')
      }.to raise_error(StandardError, 'Test error')
      
      audit_log = AuditLog.last
      expect(audit_log.event_type).to eq('admin_maintenance_failed')
      expect(audit_log.details['errors']).to include('Test error')
    end
  end

  describe 'cleanup tasks' do
    it 'removes old audit logs' do
      job = described_class.new
      
      expect {
        old_logs_count = job.send(:cleanup_old_audit_logs)
        expect(old_logs_count).to eq(5)
      }.to change(AuditLog, :count).by(-5)
    end

    it 'refreshes admin caches' do
      job = described_class.new
      
      expect(AdminCacheService).to receive(:clear_all_caches).and_return(3)
      expect(AdminCacheService).to receive(:warm_up_caches)
      
      result = job.send(:refresh_admin_caches)
      
      expect(result[:caches_cleared]).to eq(3)
      expect(result[:caches_warmed]).to be true
    end

    it 'updates inactive user stats' do
      # Create users with old last_activity_at
      inactive_users = create_list(:user, 3, last_activity_at: 2.weeks.ago)
      
      # Create recent forms for one user
      create(:form, user: inactive_users.first, created_at: 2.days.ago)
      
      job = described_class.new
      count = job.send(:update_inactive_user_stats)
      
      expect(count).to eq(3)
      
      # Check that the user with recent activity got updated
      inactive_users.first.reload
      expect(inactive_users.first.last_activity_at).to be > 1.day.ago
    end
  end

  describe 'job configuration' do
    it 'is configured with correct queue' do
      expect(described_class.queue_name).to eq('default')
    end

    it 'has retry configuration' do
      expect(described_class.retry_attempts).to eq(2)
    end
  end

  describe 'performance' do
    it 'completes full maintenance within reasonable time' do
      allow(DiscountCodeCleanupJob).to receive(:perform_now).and_return({})
      allow(AdminCacheService).to receive(:clear_all_caches).and_return(5)
      allow(AdminCacheService).to receive(:warm_up_caches)
      
      expect {
        described_class.perform_now('full')
      }.to perform_under(5.seconds)
    end

    it 'completes cleanup tasks efficiently' do
      expect {
        described_class.perform_now('cleanup')
      }.to perform_under(2.seconds)
    end
  end
end