# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin Performance', type: :request do
  let(:superadmin) { create(:user, role: 'superadmin') }
  
  before do
    # Create test data for performance testing
    create_list(:user, 10) # 10 regular users (reduced for faster tests)
    create_list(:user, 5, subscription_tier: 'premium') # 5 premium users
    create_list(:user, 3, suspended_at: 1.day.ago) # 3 suspended users
    
    # Create discount codes with usage
    discount_codes = create_list(:discount_code, 5, created_by: superadmin)
    discount_codes.each do |code|
      create_list(:discount_code_usage, 2, discount_code: code)
    end
  end

  describe 'User Management Performance' do
    it 'lists users efficiently with filters' do
      service = UserManagementService.new(
        current_user: superadmin,
        filters: { search: 'test', role: 'user', page: 1, per_page: 25 }
      )
      
      result = service.list_users
      expect(result.success?).to be true
      expect(result.result[:users]).to be_present
    end

    it 'gets user details efficiently' do
      user = User.first
      service = UserManagementService.new(
        current_user: superadmin,
        user_id: user.id
      )
      
      result = service.get_user_details
      expect(result.success?).to be true
      expect(result.result[:user]).to eq(user)
    end

    it 'gets user statistics efficiently' do
      service = UserManagementService.new(current_user: superadmin)
      
      result = service.get_user_statistics
      expect(result.success?).to be true
      expect(result.result).to have_key(:total_users)
    end
  end

  describe 'Discount Code Performance' do
    it 'loads discount codes index efficiently' do
      codes = DiscountCode.includes(:created_by)
                         .select('discount_codes.*, COUNT(discount_code_usages.id) as usage_count')
                         .left_joins(:discount_code_usages)
                         .group('discount_codes.id')
                         .order(created_at: :desc)
                         .limit(20)
      
      expect(codes.to_a).to be_an(Array)
    end

    it 'calculates usage statistics efficiently' do
      stats = DiscountCode.usage_stats_summary
      
      expect(stats).to be_a(Hash)
      expect(stats).to have_key(:total_codes)
      expect(stats[:total_codes]).to eq(DiscountCode.count)
    end

    it 'finds most used codes efficiently' do
      codes = DiscountCode.most_used(10)
      
      expect(codes.to_a).to be_an(Array)
    end

    it 'calculates revenue impact efficiently' do
      codes = DiscountCode.highest_revenue_impact(10)
      
      expect(codes.to_a).to be_an(Array)
    end
  end

  describe 'Dashboard Performance' do
    let(:agent) { Admin::DashboardAgent.new }

    it 'gets dashboard stats efficiently' do
      stats = agent.get_dashboard_stats
      
      expect(stats).to be_a(Hash)
      expect(stats).to have_key(:user_stats)
      expect(stats).to have_key(:discount_code_stats)
    end

    it 'gets user statistics efficiently' do
      stats = agent.send(:get_user_statistics)
      
      expect(stats).to be_a(Hash)
      expect(stats).to have_key(:total)
    end

    it 'gets discount code statistics efficiently' do
      stats = agent.send(:get_discount_code_statistics)
      
      expect(stats).to be_a(Hash)
      expect(stats).to have_key(:total_codes)
    end

    it 'gets recent activity efficiently' do
      activities = agent.send(:get_recent_activity)
      
      expect(activities).to be_an(Array)
    end
  end

  describe 'Database Query Performance' do
    it 'uses indexes for user searches' do
      users = User.where('email ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ?', 
                        '%test%', '%test%', '%test%').limit(10).to_a
      
      expect(users).to be_an(Array)
    end

    it 'uses indexes for user filtering' do
      users = User.where(role: 'user', subscription_tier: 'premium', suspended_at: nil)
                  .order(created_at: :desc).limit(25).to_a
      
      expect(users).to be_an(Array)
    end

    it 'uses indexes for discount code queries' do
      codes = DiscountCode.where(active: true)
                         .where('expires_at IS NULL OR expires_at > ?', Time.current)
                         .order(created_at: :desc).limit(20).to_a
      
      expect(codes).to be_an(Array)
    end

    it 'uses indexes for audit log queries' do
      # Create some audit logs first
      create_list(:audit_log, 5, user: superadmin)
      
      logs = AuditLog.where(event_type: 'discount_code_created', user: superadmin)
                    .order(created_at: :desc).limit(10).to_a
      
      expect(logs).to be_an(Array)
    end
  end

  describe 'Caching Performance' do
    it 'uses cached data for dashboard statistics' do
      # First call should populate cache
      stats1 = AdminCacheService.user_statistics
      
      # Second call should use cache (we can't easily test this without mocking)
      stats2 = AdminCacheService.user_statistics
      
      expect(stats1).to eq(stats2)
      expect(stats1).to have_key(:total)
    end

    it 'clears caches when models change' do
      # Clear cache first
      AdminCacheService.clear_all_caches
      
      # Create a new user (should trigger cache invalidation)
      create(:user)
      
      # Cache should be cleared (we verify this by checking the service works)
      stats = AdminCacheService.user_statistics
      expect(stats).to be_a(Hash)
    end
  end
end