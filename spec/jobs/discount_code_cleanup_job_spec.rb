# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscountCodeCleanupJob, type: :job do
  let(:superadmin) { create(:user, role: 'superadmin') }
  
  describe '#perform' do
    before do
      # Create test discount codes
      @active_code = create(:discount_code, created_by: superadmin, active: true)
      @expired_code = create(:discount_code, created_by: superadmin, active: true, expires_at: 1.day.ago)
      @exhausted_code = create(:discount_code, created_by: superadmin, active: true, max_usage_count: 2, current_usage_count: 2)
      @inactive_code = create(:discount_code, created_by: superadmin, active: false)
    end

    it 'deactivates expired discount codes' do
      result = described_class.perform_now
      
      expect(@expired_code.reload.active).to be false
      expect(result[:expired_codes_deactivated]).to eq(1)
    end

    it 'deactivates exhausted discount codes' do
      result = described_class.perform_now
      
      expect(@exhausted_code.reload.active).to be false
      expect(result[:exhausted_codes_deactivated]).to eq(1)
    end

    it 'does not affect active codes' do
      expect {
        described_class.perform_now
      }.not_to change { @active_code.reload.active }
    end

    it 'does not affect already inactive codes' do
      expect {
        described_class.perform_now
      }.not_to change { @inactive_code.reload.active }
    end

    it 'returns cleanup statistics' do
      result = described_class.perform_now
      
      expect(result).to be_a(Hash)
      expect(result).to have_key(:expired_codes_deactivated)
      expect(result).to have_key(:exhausted_codes_deactivated)
      expect(result).to have_key(:cache_keys_cleared)
      expect(result).to have_key(:errors)
    end

    it 'logs the cleanup activity' do
      expect {
        described_class.perform_now
      }.to change(AuditLog, :count).by(1)
      
      audit_log = AuditLog.last
      expect(audit_log.event_type).to eq('discount_code_cleanup')
      expect(audit_log.details).to have_key('expired_codes_deactivated')
      expect(audit_log.details).to have_key('exhausted_codes_deactivated')
    end

    it 'handles errors gracefully' do
      allow(DiscountCode).to receive(:where).and_raise(StandardError, 'Database error')
      
      expect {
        described_class.perform_now
      }.to raise_error(StandardError, 'Database error')
      
      # Should still log the error
      audit_log = AuditLog.last
      expect(audit_log.event_type).to eq('discount_code_cleanup_error')
      expect(audit_log.details['error']).to eq('Database error')
    end

    it 'clears related cache entries' do
      result = described_class.perform_now
      expect(result[:cache_keys_cleared]).to be > 0
    end

    it 'processes multiple expired codes efficiently' do
      # Create multiple expired codes
      create_list(:discount_code, 5, created_by: superadmin, active: true, expires_at: 1.day.ago)
      
      result = described_class.perform_now
      expect(result[:expired_codes_deactivated]).to eq(6) # 5 new + 1 existing
    end

    it 'processes multiple exhausted codes efficiently' do
      # Create multiple exhausted codes
      create_list(:discount_code, 3, created_by: superadmin, active: true, max_usage_count: 1, current_usage_count: 1)
      
      result = described_class.perform_now
      expect(result[:exhausted_codes_deactivated]).to eq(4) # 3 new + 1 existing
    end
  end

  describe 'job configuration' do
    it 'is configured with correct queue' do
      expect(described_class.queue_name).to eq('default')
    end

    it 'has retry configuration' do
      expect(described_class.retry_attempts).to eq(3)
    end
  end

  describe 'performance' do
    it 'completes cleanup efficiently with many codes' do
      # Create a large number of codes to test performance
      create_list(:discount_code, 50, created_by: superadmin, active: true, expires_at: 1.day.ago)
      
      expect {
        described_class.perform_now
      }.to perform_under(1.second)
    end
  end
end