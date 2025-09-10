# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Trial Subscription Management', type: :system do
  let(:user) { create(:user, subscription_status: 'trialing', trial_ends_at: 5.days.from_now) }

  before do
    sign_in user
  end

  describe 'trial status display' do
    it 'shows trial information for trialing users' do
      visit subscription_management_path

      expect(page).to have_content('Premium Trial')
      expect(page).to have_content('Trial Active')
      expect(page).to have_content('5 days remaining')
      expect(page).to have_content('FREE')
    end

    it 'shows progress bar for active trial' do
      visit subscription_management_path

      expect(page).to have_css('.bg-blue-600') # Progress bar
      expect(page).to have_content("Day #{TrialConfig.trial_period_days - 4} of #{TrialConfig.trial_period_days}")
    end

    it 'shows trial period details' do
      visit subscription_management_path

      expect(page).to have_content('Trial Started')
      expect(page).to have_content('Trial Expires')
      expect(page).to have_content(user.trial_ends_at.strftime('%b %d, %Y'))
    end

    it 'shows upgrade call to action' do
      visit subscription_management_path

      expect(page).to have_content('Enjoying your trial?')
      expect(page).to have_button('Upgrade Monthly ($29/month)')
      expect(page).to have_button('Upgrade Yearly ($290/year)')
    end
  end

  describe 'trial expiring soon' do
    let(:user) { create(:user, subscription_status: 'trialing', trial_ends_at: 2.days.from_now) }

    it 'shows urgent warning for trials expiring in 3 days or fewer' do
      visit subscription_management_path

      expect(page).to have_content('⚠️ Your trial expires very soon!')
      expect(page).to have_content('Trial (Expires Soon)')
      expect(page).to have_css('.bg-red-100') # Red warning badge
    end

    it 'shows urgent upgrade message' do
      visit subscription_management_path

      expect(page).to have_content("Don't lose access!")
      expect(page).to have_content('Upgrade now to ensure uninterrupted access')
    end
  end

  describe 'expired trial' do
    let(:user) { create(:user, subscription_status: 'trialing', trial_ends_at: 1.day.ago) }

    it 'shows expired trial status' do
      visit subscription_management_path

      expect(page).to have_content('Trial Expired')
      expect(page).to have_content('Your trial has ended')
      expect(page).to have_content('Upgrade now to regain access')
    end

    it 'does not show progress bar for expired trial' do
      visit subscription_management_path

      expect(page).not_to have_css('.bg-blue-600') # No progress bar
      expect(page).not_to have_content('Day')
    end
  end

  describe 'trial status messages' do
    context 'when trial expires today' do
      let(:user) { create(:user, subscription_status: 'trialing', trial_ends_at: Time.current.end_of_day) }

      it 'shows expires today message' do
        visit subscription_management_path

        expect(page).to have_content('Your trial expires today')
      end
    end

    context 'when trial expires in 7 days' do
      let(:user) { create(:user, subscription_status: 'trialing', trial_ends_at: 7.days.from_now) }

      it 'shows expires soon warning' do
        visit subscription_management_path

        expect(page).to have_content('7 days left in your trial')
        expect(page).to have_content('Trial (Expires Soon)')
        expect(page).to have_css('.bg-yellow-100') # Yellow warning badge
      end
    end

    context 'when trial has many days remaining' do
      let(:user) { create(:user, subscription_status: 'trialing', trial_ends_at: 10.days.from_now) }

      it 'shows active trial message' do
        visit subscription_management_path

        expect(page).to have_content('Trial active (10 days remaining)')
        expect(page).to have_content('Trial Active')
        expect(page).to have_css('.bg-blue-100') # Blue active badge
      end
    end
  end
end