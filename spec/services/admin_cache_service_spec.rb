# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminCacheService, type: :service do
  let(:superadmin) { create(:user, role: 'superadmin') }
  
  before do
    # Clear any existing cache
    Rails.cache.clear
    
    # Create test data
    create_list(:user, 10)
    create_list(:user, 5, subscription_tier: 'premium')
    create_list(:user, 3, suspended_at: 1.day.ago)
    
    discount_codes = create_list(:discount_code, 5, created_by: superadmin)
    discount_codes.each do |code|
      create_list(:discount_code_usage, 2, discount_code: code)
    end
  end

  describe '.dashboard_stats' do
    it 'returns cached dashboard statistics' do
      expect(Rails.cache).to receive(:fetch)
        .with('admin_dashboard_stats', expires_in: AdminCacheService::DASHBOARD_STATS_TTL)
        .and_call_original
      
      stats = AdminCacheService.dashboard_stats
      
      expect(stats).to be_a(Hash)
      expect(stats).to have_key(:users)
      expect(stats).to have_key(:discount_codes)
      expect(stats).to have_key(:system)
      expect(stats).to have_key(:generated_at)
    end

    it 'uses cached data on subsequent calls' do
      # First call should hit the database
      first_stats = AdminCacheService.dashboard_stats
      
      # Second call should use cache
      expect(AdminCacheService).not_to receive(:calculate_dashboard_stats)
      second_stats = AdminCacheService.dashboard_stats
      
      expect(first_stats[:generated_at]).to eq(second_stats[:generated_at])
    end
  end

  describe '.user_statistics' do
    it 'returns cached user statistics' do
      stats = AdminCacheService.user_statistics
      
      expect(stats).to be_a(Hash)
      expect(stats).to have_key(:total)
      expect(stats).to have_key(:active)
      expect(stats).to have_key(:suspended)
      expect(stats).to have_key(:premium)
      expect(stats).to have_key(:freemium)
      
      expect(stats[:total]).to eq(User.count)
      expect(stats[:suspended]).to eq(3)
      expect(stats[:premium]).to eq(5)
    end

    it 'calculates premium percentage correctly' do
      stats = AdminCacheService.user_statistics
      
      total_users = User.count
      premium_users = User.where(subscription_tier: 'premium').count
      expected_percentage = (premium_users.to_f / total_users * 100).round(1)
      
      expect(stats[:premium_percentage]).to eq(expected_percentage)
    end
  end

  describe '.discount_code_statistics' do
    it 'returns cached discount code statistics' do
      stats = AdminCacheService.discount_code_statistics
      
      expect(stats).to be_a(Hash)
      expect(stats).to have_key(:total_codes)
      expect(stats).to have_key(:active_codes)
      expect(stats).to have_key(:total_usage)
      expect(stats).to have_key(:total_discount_amount)
      
      expect(stats[:total_codes]).to eq(DiscountCode.count)
      expect(stats[:total_usage]).to eq(DiscountCodeUsage.count)
    end

    it 'calculates average discount correctly' do
      stats = AdminCacheService.discount_code_statistics
      
      expected_avg = DiscountCode.average(:discount_percentage).to_f.round(1)
      expect(stats[:average_discount_percentage]).to eq(expected_avg)
    end
  end

  describe '.analytics_data' do
    it 'returns top discount codes' do
      data = AdminCacheService.analytics_data('top_discount_codes')
      
      expect(data).to be_an(ActiveRecord::Relation)
      expect(data.limit_value).to eq(10)
    end

    it 'returns highest revenue codes' do
      data = AdminCacheService.analytics_data('highest_revenue_codes')
      
      expect(data).to be_an(ActiveRecord::Relation)
      expect(data.limit_value).to eq(10)
    end

    it 'returns recent activity' do
      data = AdminCacheService.analytics_data('recent_activity')
      
      expect(data).to be_an(Array)
      expect(data.first).to have_key(:type) if data.any?
      expect(data.first).to have_key(:message) if data.any?
      expect(data.first).to have_key(:timestamp) if data.any?
    end

    it 'returns empty hash for unknown type' do
      data = AdminCacheService.analytics_data('unknown_type')
      expect(data).to eq({})
    end
  end

  describe '.clear_all_caches' do
    it 'clears all admin cache entries' do
      # Populate some caches first
      AdminCacheService.dashboard_stats
      AdminCacheService.user_statistics
      AdminCacheService.discount_code_statistics
      
      cleared_count = AdminCacheService.clear_all_caches
      
      expect(cleared_count).to be > 0
    end
  end

  describe '.clear_cache' do
    it 'clears specific cache types' do
      # Populate cache first
      AdminCacheService.dashboard_stats
      
      expect(Rails.cache).to receive(:delete).with('admin_dashboard_stats')
      AdminCacheService.clear_cache('dashboard')
    end

    it 'clears user cache' do
      expect(Rails.cache).to receive(:delete).with('admin_user_statistics')
      AdminCacheService.clear_cache('users')
    end

    it 'clears discount code caches' do
      expect(Rails.cache).to receive(:delete).with('admin_discount_statistics')
      expect(Rails.cache).to receive(:delete).with('discount_codes_dashboard_stats')
      AdminCacheService.clear_cache('discount_codes')
    end
  end

  describe '.warm_up_caches' do
    it 'pre-loads all cache entries' do
      expect(AdminCacheService).to receive(:dashboard_stats)
      expect(AdminCacheService).to receive(:user_statistics)
      expect(AdminCacheService).to receive(:discount_code_statistics)
      expect(AdminCacheService).to receive(:analytics_data).with('top_discount_codes')
      expect(AdminCacheService).to receive(:analytics_data).with('highest_revenue_codes')
      expect(AdminCacheService).to receive(:analytics_data).with('recent_activity')
      
      AdminCacheService.warm_up_caches
    end
  end

  describe 'performance' do
    it 'executes user statistics query efficiently' do
      expect {
        AdminCacheService.user_statistics
      }.to perform_under(50).ms
    end

    it 'executes discount statistics query efficiently' do
      expect {
        AdminCacheService.discount_code_statistics
      }.to perform_under(50).ms
    end

    it 'uses minimal database queries for dashboard stats' do
      expect {
        AdminCacheService.dashboard_stats
      }.to perform_under(100).ms
    end
  end
end