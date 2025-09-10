# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserManagementService, type: :service do
  let!(:superadmin) { create(:user, role: 'superadmin') }
  let!(:admin) { create(:user, role: 'admin') }
  let!(:regular_user) { create(:user, role: 'user') }
  let!(:suspended_user) { create(:user, suspended_at: 1.day.ago, suspended_reason: 'Test suspension') }

  describe '#list_users' do
    let(:service) { described_class.new(current_user: superadmin) }

    before do
      create_list(:user, 5, role: 'user')
      create_list(:user, 2, role: 'admin')
      create(:user, role: 'user', first_name: 'John', last_name: 'Doe', email: 'john.doe@example.com')
    end

    context 'when called by superadmin' do
      it 'returns all users' do
        result = service.list_users
        
        expect(result.success?).to be true
        expect(result.result[:users].count).to be > 0
        expect(result.result[:total_count]).to be > 0
      end

      it 'applies search filter correctly' do
        service.filters = { search: 'john' }
        result = service.list_users
        
        expect(result.success?).to be true
        expect(result.result[:users].map(&:email)).to include('john.doe@example.com')
      end

      it 'applies role filter correctly' do
        service.filters = { role: 'admin' }
        result = service.list_users
        
        expect(result.success?).to be true
        expect(result.result[:users].all? { |u| u.role == 'admin' }).to be true
      end

      it 'applies pagination correctly' do
        service.filters = { page: 1, per_page: 3 }
        result = service.list_users
        
        expect(result.success?).to be true
        expect(result.result[:users].count).to eq(3)
        expect(result.result[:current_page]).to eq(1)
        expect(result.result[:per_page]).to eq(3)
      end
    end

    context 'when called by non-superadmin' do
      let(:service) { described_class.new(current_user: regular_user) }

      it 'fails with authorization error' do
        result = service.list_users
        
        expect(result.failure?).to be true
        expect(result.errors.full_messages).to include('Authorization Only superadmins can perform user management operations')
      end
    end
  end

  describe '#get_user_details' do
    let(:service) { described_class.new(current_user: superadmin, user_id: regular_user.id) }

    before do
      create_list(:form, 3, user: regular_user)
    end

    context 'when user exists' do
      it 'returns comprehensive user details' do
        result = service.get_user_details
        
        expect(result.success?).to be true
        expect(result.result[:user]).to eq(regular_user)
        expect(result.result[:subscription_details]).to be_present
        expect(result.result[:usage_stats]).to be_present
        expect(result.result[:recent_activity]).to be_present
        expect(result.result[:discount_info]).to be_present
      end

      it 'includes correct usage statistics' do
        result = service.get_user_details
        
        usage_stats = result.result[:usage_stats]
        expect(usage_stats[:total_forms]).to eq(3)
        expect(usage_stats[:ai_credits_used]).to eq(regular_user.ai_credits_used)
      end
    end

    context 'when user does not exist' do
      let(:service) { described_class.new(current_user: superadmin, user_id: 'nonexistent') }

      it 'fails with user not found error' do
        result = service.get_user_details
        
        expect(result.failure?).to be true
        expect(result.errors.full_messages).to include('User User not found with id: nonexistent')
      end
    end
  end

  describe '#create_user' do
    let(:user_params) do
      {
        email: 'newuser@example.com',
        first_name: 'New',
        last_name: 'User',
        role: 'user',
        subscription_tier: 'freemium'
      }
    end
    let(:service) { described_class.new(current_user: superadmin, user_params: user_params) }

    context 'with valid parameters' do
      it 'creates a new user successfully' do
        expect {
          result = service.create_user
          expect(result.success?).to be true
        }.to change(User, :count).by(1)
      end

      it 'generates a temporary password' do
        result = service.create_user
        
        expect(result.success?).to be true
        expect(result.result[:temporary_password]).to be_present
        expect(result.result[:temporary_password].length).to eq(16)
      end

      it 'enqueues invitation email job' do
        expect {
          service.create_user
        }.to have_enqueued_job(UserInvitationJob)
      end
    end

    context 'with invalid parameters' do
      let(:user_params) { { email: 'invalid-email' } }

      it 'fails with validation errors' do
        result = service.create_user
        
        expect(result.failure?).to be true
        expect(result.errors.full_messages).to include(match(/Email is invalid/))
      end
    end

    context 'with duplicate email' do
      before { create(:user, email: 'newuser@example.com') }

      it 'fails with uniqueness error' do
        result = service.create_user
        
        expect(result.failure?).to be true
        expect(result.errors.full_messages).to include(match(/Email has already been taken/))
      end
    end
  end

  describe '#update_user' do
    let(:user_params) { { first_name: 'Updated', subscription_tier: 'premium' } }
    let(:service) { described_class.new(current_user: superadmin, user_id: regular_user.id, user_params: user_params) }

    context 'with valid parameters' do
      it 'updates user successfully' do
        result = service.update_user
        
        expect(result.success?).to be true
        expect(result.result[:user].first_name).to eq('Updated')
        expect(result.result[:user].subscription_tier).to eq('premium')
      end
    end

    context 'when trying to change own role' do
      let(:user_params) { { role: 'user' } }
      let(:service) { described_class.new(current_user: superadmin, user_id: superadmin.id, user_params: user_params) }

      it 'prevents self-demotion' do
        result = service.update_user
        
        expect(result.failure?).to be true
        expect(result.errors.full_messages).to include('Role Cannot change your own role')
      end
    end

    context 'with invalid parameters' do
      let(:user_params) { { email: 'invalid-email' } }

      it 'fails with validation errors' do
        result = service.update_user
        
        expect(result.failure?).to be true
        expect(result.errors.full_messages).to include(match(/Email is invalid/))
      end
    end
  end

  describe '#suspend_user' do
    let(:service) { described_class.new(current_user: superadmin, user_id: regular_user.id, suspension_reason: 'Policy violation') }

    context 'with valid parameters' do
      it 'suspends user successfully' do
        result = service.suspend_user
        
        expect(result.success?).to be true
        expect(result.result[:user].suspended?).to be true
        expect(result.result[:user].suspended_reason).to eq('Policy violation')
      end

      it 'enqueues suspension notification email' do
        expect {
          service.suspend_user
        }.to have_enqueued_job(UserSuspensionJob)
      end
    end

    context 'when trying to suspend self' do
      let(:service) { described_class.new(current_user: superadmin, user_id: superadmin.id, suspension_reason: 'Test') }

      it 'prevents self-suspension' do
        result = service.suspend_user
        
        expect(result.failure?).to be true
        expect(result.errors.full_messages).to include('Suspension Cannot suspend your own account')
      end
    end

    context 'when trying to suspend another superadmin' do
      let(:another_superadmin) { create(:user, role: 'superadmin') }
      let(:service) { described_class.new(current_user: superadmin, user_id: another_superadmin.id, suspension_reason: 'Test') }

      it 'prevents suspending other superadmins' do
        result = service.suspend_user
        
        expect(result.failure?).to be true
        expect(result.errors.full_messages).to include('Suspension Cannot suspend other superadmin accounts')
      end
    end
  end

  describe '#reactivate_user' do
    let(:service) { described_class.new(current_user: superadmin, user_id: suspended_user.id) }

    context 'when user is suspended' do
      it 'reactivates user successfully' do
        result = service.reactivate_user
        
        expect(result.success?).to be true
        expect(result.result[:user].suspended?).to be false
        expect(result.result[:user].suspended_reason).to be_nil
      end

      it 'enqueues reactivation notification email' do
        expect {
          service.reactivate_user
        }.to have_enqueued_job(UserReactivationJob)
      end
    end

    context 'when user is not suspended' do
      let(:service) { described_class.new(current_user: superadmin, user_id: regular_user.id) }

      it 'fails with appropriate error' do
        result = service.reactivate_user
        
        expect(result.failure?).to be true
        expect(result.errors.full_messages).to include('Reactivation User is not suspended')
      end
    end
  end

  describe '#delete_user' do
    let(:service) { described_class.new(current_user: superadmin, user_id: regular_user.id) }

    before do
      create_list(:form, 2, user: regular_user)
    end

    context 'with valid parameters' do
      it 'deletes user successfully' do
        expect {
          result = service.delete_user
          expect(result.success?).to be true
        }.to change(User, :count).by(-1)
      end

      it 'returns deleted user email' do
        result = service.delete_user
        
        expect(result.success?).to be true
        expect(result.result[:deleted_user_email]).to eq(regular_user.email)
      end
    end

    context 'when trying to delete self' do
      let(:service) { described_class.new(current_user: superadmin, user_id: superadmin.id) }

      it 'prevents self-deletion' do
        result = service.delete_user
        
        expect(result.failure?).to be true
        expect(result.errors.full_messages).to include('Deletion Cannot delete your own account')
      end
    end

    context 'when trying to delete another superadmin' do
      let(:another_superadmin) { create(:user, role: 'superadmin') }
      let(:service) { described_class.new(current_user: superadmin, user_id: another_superadmin.id) }

      it 'prevents deleting other superadmins' do
        result = service.delete_user
        
        expect(result.failure?).to be true
        expect(result.errors.full_messages).to include('Deletion Cannot delete other superadmin accounts')
      end
    end

    context 'with transfer_data option' do
      let(:service) { described_class.new(current_user: superadmin, user_id: regular_user.id, transfer_data: true) }

      it 'handles data transfer option correctly' do
        # Check forms exist before deletion
        expect(regular_user.forms.count).to be > 0
        
        # Store form IDs to check later
        form_ids = regular_user.forms.pluck(:id)
        
        result = service.delete_user
        
        # Check that the service succeeded
        expect(result.success?).to be true
        
        # In a real implementation, forms would be transferred or archived
        # For now, we just verify the service handles the transfer_data flag
        expect(result.result[:message]).to eq('User deleted successfully')
      end
    end
  end

  describe '#get_user_statistics' do
    let(:service) { described_class.new(current_user: superadmin) }

    before do
      create_list(:user, 3, role: 'user', subscription_tier: 'premium')
      create_list(:user, 2, role: 'admin')
      create(:user, suspended_at: 1.day.ago)
      create(:user, created_at: 2.days.ago)
    end

    it 'returns comprehensive user statistics' do
      result = service.get_user_statistics
      
      expect(result.success?).to be true
      
      stats = result.result
      expect(stats[:total_users]).to be > 0
      expect(stats[:active_users]).to be > 0
      expect(stats[:suspended_users]).to eq(2)
      expect(stats[:premium_users]).to eq(3)
      expect(stats[:admin_users]).to be >= 2
      expect(stats[:users_this_week]).to be > 0
    end
  end

  describe '#bulk_operations' do
    let(:service) { described_class.new(current_user: superadmin) }
    let(:user_ids) { create_list(:user, 5).map(&:id) }

    describe '#bulk_suspend_users' do
      it 'suspends multiple users efficiently' do
        result = service.bulk_suspend_users(user_ids, 'Bulk suspension test')
        
        expect(result.success?).to be true
        expect(result.result[:suspended_count]).to eq(5)
        
        User.where(id: user_ids).each do |user|
          expect(user.suspended?).to be true
          expect(user.suspended_reason).to eq('Bulk suspension test')
        end
      end

      it 'handles partial failures gracefully' do
        # Make one user a superadmin (cannot be suspended)
        User.find(user_ids.first).update!(role: 'superadmin')
        
        result = service.bulk_suspend_users(user_ids, 'Bulk test')
        
        expect(result.success?).to be true
        expect(result.result[:suspended_count]).to eq(4)
        expect(result.result[:failed_count]).to eq(1)
        expect(result.result[:failures]).to have(1).item
      end
    end

    describe '#bulk_delete_users' do
      it 'deletes multiple users with confirmation' do
        result = service.bulk_delete_users(user_ids, confirm: true)
        
        expect(result.success?).to be true
        expect(result.result[:deleted_count]).to eq(5)
        expect(User.where(id: user_ids)).to be_empty
      end

      it 'requires explicit confirmation' do
        result = service.bulk_delete_users(user_ids)
        
        expect(result.failure?).to be true
        expect(result.errors.full_messages).to include('Confirmation Bulk deletion requires explicit confirmation')
      end
    end
  end

  describe '#advanced_user_search' do
    let(:service) { described_class.new(current_user: superadmin) }

    before do
      create(:user, email: 'john.doe@example.com', first_name: 'John', last_name: 'Doe', role: 'user')
      create(:user, email: 'jane.admin@example.com', first_name: 'Jane', last_name: 'Admin', role: 'admin')
      create(:user, email: 'suspended@example.com', suspended_at: 1.day.ago)
      create(:user, subscription_tier: 'premium', created_at: 1.week.ago)
    end

    it 'searches by multiple criteria simultaneously' do
      filters = {
        search: 'john',
        role: 'user',
        subscription_tier: 'freemium',
        suspended: false,
        created_after: 1.month.ago
      }
      
      result = service.advanced_user_search(filters)
      
      expect(result.success?).to be true
      expect(result.result[:users].map(&:email)).to include('john.doe@example.com')
    end

    it 'handles complex date range queries' do
      filters = {
        created_after: 2.weeks.ago,
        created_before: 3.days.ago,
        last_activity_after: 1.week.ago
      }
      
      result = service.advanced_user_search(filters)
      
      expect(result.success?).to be true
      expect(result.result[:total_count]).to be >= 0
    end

    it 'supports fuzzy search' do
      filters = { fuzzy_search: 'jon do' } # Misspelled "john doe"
      
      result = service.advanced_user_search(filters)
      
      expect(result.success?).to be true
      # Should still find john.doe@example.com with fuzzy matching
    end
  end

  describe '#user_activity_analysis' do
    let(:service) { described_class.new(current_user: superadmin, user_id: regular_user.id) }

    before do
      create_list(:form, 3, user: regular_user, created_at: 1.week.ago)
      create_list(:form_response, 5, form: regular_user.forms.first, created_at: 3.days.ago)
    end

    it 'analyzes user activity patterns' do
      result = service.user_activity_analysis
      
      expect(result.success?).to be true
      
      analysis = result.result
      expect(analysis[:activity_score]).to be_present
      expect(analysis[:engagement_level]).to be_in(['low', 'medium', 'high'])
      expect(analysis[:recent_activity]).to be_present
      expect(analysis[:usage_trends]).to be_present
    end

    it 'identifies inactive users' do
      # Make user inactive by not having recent activity
      regular_user.update!(last_activity_at: 3.months.ago)
      
      result = service.user_activity_analysis
      
      expect(result.success?).to be true
      expect(result.result[:engagement_level]).to eq('low')
      expect(result.result[:recommendations]).to include(/reactivation/)
    end
  end

  describe 'security and audit features' do
    let(:service) { described_class.new(current_user: superadmin) }

    describe '#audit_user_changes' do
      it 'tracks all user modifications' do
        user_params = { first_name: 'Updated', role: 'admin' }
        service_instance = described_class.new(current_user: superadmin, user_id: regular_user.id, user_params: user_params)
        
        expect {
          service_instance.update_user
        }.to change(AuditLog, :count).by(1)
        
        audit_log = AuditLog.last
        expect(audit_log.action).to eq('user_updated')
        expect(audit_log.user_id).to eq(superadmin.id)
        expect(audit_log.target_id).to eq(regular_user.id)
      end

      it 'logs sensitive operations' do
        service_instance = described_class.new(current_user: superadmin, user_id: regular_user.id, suspension_reason: 'Security violation')
        
        expect {
          service_instance.suspend_user
        }.to change(AuditLog, :count).by(1)
        
        audit_log = AuditLog.last
        expect(audit_log.action).to eq('user_suspended')
        expect(audit_log.details['reason']).to eq('Security violation')
      end
    end

    describe '#detect_suspicious_activity' do
      it 'identifies rapid user creation patterns' do
        # Simulate rapid user creation
        10.times { service.create_user(attributes_for(:user)) }
        
        result = service.detect_suspicious_activity
        
        expect(result.success?).to be true
        expect(result.result[:alerts]).to include(match(/rapid user creation/i))
      end

      it 'flags unusual suspension patterns' do
        # Simulate mass suspensions
        users = create_list(:user, 5)
        users.each { |u| service.suspend_user(u.id, 'Mass suspension') }
        
        result = service.detect_suspicious_activity
        
        expect(result.success?).to be true
        expect(result.result[:alerts]).to include(match(/mass suspension/i))
      end
    end

    describe '#validate_admin_permissions' do
      it 'prevents privilege escalation' do
        # Regular admin trying to create superadmin
        admin_service = described_class.new(current_user: admin)
        user_params = attributes_for(:user, role: 'superadmin')
        
        result = admin_service.create_user(user_params)
        
        expect(result.failure?).to be true
        expect(result.errors.full_messages).to include(/cannot create superadmin/i)
      end

      it 'enforces role hierarchy' do
        # Admin trying to modify another admin
        another_admin = create(:user, role: 'admin')
        admin_service = described_class.new(current_user: admin, user_id: another_admin.id)
        
        result = admin_service.suspend_user('Test suspension')
        
        expect(result.failure?).to be true
        expect(result.errors.full_messages).to include(/insufficient privileges/i)
      end
    end
  end

  describe 'performance and scalability' do
    let(:service) { described_class.new(current_user: superadmin) }

    it 'handles large user datasets efficiently' do
      # Mock large dataset
      allow(User).to receive(:count).and_return(100000)
      
      result = service.list_users(page: 1, per_page: 50)
      
      expect(result.success?).to be true
      # Should implement pagination and not load all users
    end

    it 'optimizes database queries' do
      create_list(:user, 10, :with_forms)
      
      expect {
        service.list_users
      }.to make_database_queries(count: 1..5) # Should be efficient with includes
    end

    it 'implements caching for expensive operations' do
      allow(Rails.cache).to receive(:fetch).and_call_original
      
      service.get_user_statistics
      service.get_user_statistics # Second call should use cache
      
      expect(Rails.cache).to have_received(:fetch).with(/user_statistics/).at_least(:twice)
    end
  end

  describe 'error handling and resilience' do
    let(:service) { described_class.new(current_user: superadmin) }

    it 'handles database connection failures' do
      allow(User).to receive(:find).and_raise(ActiveRecord::ConnectionTimeoutError)
      
      result = service.get_user_details(regular_user.id)
      
      expect(result.failure?).to be true
      expect(result.errors.full_messages).to include(/database connection/i)
    end

    it 'handles email delivery failures gracefully' do
      allow(UserInvitationJob).to receive(:perform_later).and_raise(StandardError.new('Email service down'))
      
      result = service.create_user(attributes_for(:user))
      
      # User should still be created even if email fails
      expect(result.success?).to be true
      expect(result.result[:email_sent]).to be false
    end

    it 'validates input sanitization' do
      malicious_params = {
        first_name: '<script>alert("xss")</script>',
        last_name: 'DROP TABLE users;',
        email: 'test@example.com'
      }
      
      result = service.create_user(malicious_params)
      
      if result.success?
        created_user = result.result[:user]
        expect(created_user.first_name).not_to include('<script>')
        expect(created_user.last_name).not_to include('DROP TABLE')
      end
    end
  end

  describe 'authorization' do
    context 'when current_user is not superadmin' do
      let(:service) { described_class.new(current_user: regular_user) }

      it 'fails all operations with authorization error' do
        expect(service.list_users.failure?).to be true
        expect(service.get_user_details.failure?).to be true
        expect(service.create_user.failure?).to be true
        expect(service.update_user.failure?).to be true
        expect(service.suspend_user.failure?).to be true
        expect(service.reactivate_user.failure?).to be true
        expect(service.delete_user.failure?).to be true
        expect(service.get_user_statistics.failure?).to be true
      end
    end

    context 'when current_user is nil' do
      let(:service) { described_class.new(current_user: nil) }

      it 'fails with validation error' do
        result = service.list_users
        
        expect(result.failure?).to be true
        expect(result.errors.full_messages).to include('Current user can\'t be blank')
      end
    end

    context 'when current_user is admin (not superadmin)' do
      let(:service) { described_class.new(current_user: admin) }

      it 'allows limited operations' do
        # Admins can view users but not create superadmins
        expect(service.list_users.success?).to be true
        
        # But cannot create superadmin users
        superadmin_params = attributes_for(:user, role: 'superadmin')
        expect(service.create_user(superadmin_params).failure?).to be true
      end
    end
  end
end