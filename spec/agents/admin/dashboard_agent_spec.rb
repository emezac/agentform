require 'rails_helper'

RSpec.describe Admin::DashboardAgent, type: :agent do
  let(:agent) { described_class.new }

  describe '#get_dashboard_stats' do
    it 'returns a hash with all required statistics' do
      stats = agent.get_dashboard_stats

      expect(stats).to have_key(:user_stats)
      expect(stats).to have_key(:subscription_stats)
      expect(stats).to have_key(:discount_code_stats)
      expect(stats).to have_key(:recent_activity)
      expect(stats).to have_key(:quick_actions)
    end
  end

  describe '#get_user_statistics' do
    let!(:freemium_users) { create_list(:user, 3, subscription_tier: 'freemium') }
    let!(:premium_users) { create_list(:user, 2, subscription_tier: 'premium') }
    let!(:suspended_user) { create(:user, suspended_at: 1.day.ago, suspended_reason: 'Spam') }
    let!(:old_premium_user) { create(:user, created_at: 2.weeks.ago, subscription_tier: 'premium') }

    it 'returns accurate user statistics' do
      # Get current counts to account for any existing data
      total_users = User.count
      active_users = User.where(suspended_at: nil).count
      suspended_users = User.where.not(suspended_at: nil).count
      premium_users_count = User.where(subscription_tier: 'premium').count
      freemium_users_count = User.where(subscription_tier: 'freemium').count
      new_users_this_month = User.where(created_at: 1.month.ago..Time.current).count
      
      stats = agent.send(:get_user_statistics)

      expect(stats[:total]).to eq(total_users)
      expect(stats[:active]).to eq(active_users)
      expect(stats[:suspended]).to eq(suspended_users)
      expect(stats[:premium]).to eq(premium_users_count)
      expect(stats[:freemium]).to eq(freemium_users_count)
      expect(stats[:new_this_month]).to eq(new_users_this_month)
      expect(stats[:premium_percentage]).to eq((premium_users_count.to_f / total_users * 100).round(1))
    end

    context 'with no users' do
      before { User.destroy_all }

      it 'handles empty database gracefully' do
        stats = agent.send(:get_user_statistics)

        expect(stats[:total]).to eq(0)
        expect(stats[:premium_percentage]).to eq(0)
      end
    end
  end

  describe '#get_subscription_statistics' do
    let!(:premium_users) { create_list(:user, 3, subscription_tier: 'premium') }
    let!(:freemium_users) { create_list(:user, 2, subscription_tier: 'freemium') }
    let!(:suspended_premium_user) { create(:user, subscription_tier: 'premium', suspended_at: 1.day.ago) }
    let!(:old_premium_user) { create(:user, subscription_tier: 'premium', created_at: 2.weeks.ago) }

    it 'returns accurate subscription statistics' do
      # Get current counts to account for any existing data
      total_premium = User.where(subscription_tier: 'premium').count
      active_premium = User.where(subscription_tier: 'premium', suspended_at: nil).count
      new_premium_this_month = User.where(
        subscription_tier: 'premium',
        created_at: 1.month.ago..Time.current
      ).count
      total_users = User.count
      
      stats = agent.send(:get_subscription_statistics)

      expect(stats[:total]).to eq(total_premium)
      expect(stats[:active]).to eq(active_premium)
      expect(stats[:mrr]).to eq(active_premium * 35)
      expect(stats[:new_this_month]).to eq(new_premium_this_month)
      expect(stats[:conversion_rate]).to eq((total_premium.to_f / total_users * 100).round(2))
    end
  end

  describe '#get_discount_code_statistics' do
    let!(:test_user1) { create(:user) }
    let!(:test_user2) { create(:user) }
    let!(:active_code) { create(:discount_code, active: true, discount_percentage: 20) }
    let!(:expired_code) { create(:discount_code, expires_at: 1.day.ago, active: true) }
    let!(:inactive_code) { create(:discount_code, active: false) }
    let!(:usage1) do
      create(:discount_code_usage, 
             discount_code: active_code, 
             user: test_user1, 
             original_amount: 5000,
             discount_amount: 700,
             final_amount: 4300)
    end
    let!(:usage2) do
      create(:discount_code_usage, 
             discount_code: active_code, 
             user: test_user2, 
             original_amount: 7000,
             discount_amount: 1050,
             final_amount: 5950)
    end

    it 'returns accurate discount code statistics' do
      # Get current counts to account for any existing data
      total_codes = DiscountCode.count
      available_codes = DiscountCode.available.count
      expired_codes = DiscountCode.expired.count
      total_usage = DiscountCodeUsage.count
      total_discount_amount = DiscountCodeUsage.sum(:discount_amount)
      
      stats = agent.send(:get_discount_code_statistics)

      expect(stats[:total_codes]).to eq(total_codes)
      expect(stats[:active_codes]).to eq(available_codes)
      expect(stats[:expired_codes]).to eq(expired_codes)
      expect(stats[:total_usage]).to eq(total_usage)
      expect(stats[:total_discount_amount]).to eq(total_discount_amount)
      expect(stats[:average_discount_per_use]).to eq(total_usage > 0 ? (total_discount_amount.to_f / total_usage).round(2) : 0)
    end

    context 'with no discount codes' do
      before do
        DiscountCode.destroy_all
        DiscountCodeUsage.destroy_all
      end

      it 'handles empty database gracefully' do
        stats = agent.send(:get_discount_code_statistics)

        expect(stats[:total_codes]).to eq(0)
        expect(stats[:average_discount_per_use]).to eq(0)
      end
    end
  end

  describe '#get_recent_activity' do
    let!(:recent_user) { create(:user, email: 'new@example.com', created_at: 1.hour.ago) }
    let!(:suspended_user) { create(:user, email: 'suspended@example.com', 
                                   suspended_at: 30.minutes.ago, 
                                   suspended_reason: 'Spam activity') }
    let!(:test_discount_code) { create(:discount_code, code: 'WELCOME20') }
    let!(:recent_usage) do
      create(:discount_code_usage, 
             discount_code: test_discount_code, 
             user: recent_user, 
             created_at: 45.minutes.ago)
    end

    it 'returns recent activities sorted by timestamp' do
      activities = agent.send(:get_recent_activity)

      expect(activities).to be_an(Array)
      expect(activities.length).to be <= 10
      
      # Check that activities are sorted by timestamp (most recent first)
      timestamps = activities.map { |a| a[:timestamp] }
      expect(timestamps).to eq(timestamps.sort.reverse)
      
      # Check activity types
      activity_types = activities.map { |a| a[:type] }
      expect(activity_types).to include('user_registration')
      expect(activity_types).to include('discount_usage')
      expect(activity_types).to include('user_suspension')
    end

    it 'includes proper activity structure' do
      activities = agent.send(:get_recent_activity)
      
      activities.each do |activity|
        expect(activity).to have_key(:type)
        expect(activity).to have_key(:message)
        expect(activity).to have_key(:timestamp)
        expect(activity).to have_key(:icon)
        expect(activity).to have_key(:color)
      end
    end
  end

  describe '#get_quick_actions' do
    it 'returns an array of quick action items' do
      actions = agent.send(:get_quick_actions)

      expect(actions).to be_an(Array)
      expect(actions.length).to eq(4)
      
      actions.each do |action|
        expect(action).to have_key(:title)
        expect(action).to have_key(:description)
        expect(action).to have_key(:url)
        expect(action).to have_key(:icon)
        expect(action).to have_key(:color)
      end
    end

    it 'includes expected quick actions' do
      actions = agent.send(:get_quick_actions)
      titles = actions.map { |a| a[:title] }

      expect(titles).to include('Create Discount Code')
      expect(titles).to include('Manage Users')
      expect(titles).to include('View Discount Codes')
      expect(titles).to include('Export Data')
    end
  end

  describe '#calculate_conversion_rate' do
    context 'with users' do
      let!(:test_freemium_users) { create_list(:user, 3, subscription_tier: 'freemium') }
      let!(:test_premium_users) { create_list(:user, 2, subscription_tier: 'premium') }

      it 'calculates the correct conversion rate' do
        total_users = User.count
        premium_users = User.where(subscription_tier: 'premium').count
        expected_rate = (premium_users.to_f / total_users * 100).round(2)
        
        rate = agent.send(:calculate_conversion_rate)
        expect(rate).to eq(expected_rate)
      end
    end

    context 'with no users' do
      before { User.destroy_all }

      it 'returns 0 when no users exist' do
        rate = agent.send(:calculate_conversion_rate)
        expect(rate).to eq(0)
      end
    end
  end
end