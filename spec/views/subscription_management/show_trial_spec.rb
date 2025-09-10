# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'subscription_management/show.html.erb', type: :view do
  let(:subscription_service) { instance_double('SubscriptionManagementService') }

  before do
    assign(:subscription_service, subscription_service)
    allow(subscription_service).to receive(:user_has_active_subscription?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
  end

  describe 'trial status display' do
    context 'when user is in trial period' do
      let(:user) { create(:user, subscription_status: 'trialing', trial_ends_at: 5.days.from_now) }

      it 'shows trial status section' do
        render

        expect(rendered).to have_content('Premium Trial')
        expect(rendered).to have_content('Trial (Expires Soon)') # 5 days triggers expires_soon
        expect(rendered).to have_content('FREE')
        expect(rendered).to have_content('5 days remaining')
      end

      it 'shows trial progress bar' do
        render

        expect(rendered).to have_css('.bg-blue-600') # Progress bar
        expect(rendered).to have_content("Day #{TrialConfig.trial_period_days - 4} of #{TrialConfig.trial_period_days}")
      end

      it 'shows trial period details' do
        render

        expect(rendered).to have_content('Trial Started')
        expect(rendered).to have_content('Trial Expires')
        expect(rendered).to have_content(user.trial_ends_at.strftime('%b %d, %Y'))
      end

      it 'shows upgrade call to action' do
        render

        expect(rendered).to have_content('Enjoying your trial?')
        expect(rendered).to have_button('Upgrade Monthly ($29/month)')
        expect(rendered).to have_button('Upgrade Yearly ($290/year)')
      end
    end

    context 'when trial expires soon (3 days or fewer)' do
      let(:user) { create(:user, subscription_status: 'trialing', trial_ends_at: 2.days.from_now) }

      it 'shows urgent warning' do
        render

        expect(rendered).to have_content('⚠️ Your trial expires very soon!')
        expect(rendered).to have_content('Trial (Expires Soon)')
        expect(rendered).to have_css('.bg-red-100') # Red warning badge
      end

      it 'shows urgent upgrade message' do
        render

        expect(rendered).to have_content("Don't lose access!")
        expect(rendered).to have_content('Upgrade now to ensure uninterrupted access')
      end
    end

    context 'when trial expires in 7 days' do
      let(:user) { create(:user, subscription_status: 'trialing', trial_ends_at: 7.days.from_now) }

      it 'shows expires soon warning' do
        render

        expect(rendered).to have_content('7 days left in your trial')
        expect(rendered).to have_content('Trial (Expires Soon)')
        expect(rendered).to have_css('.bg-yellow-100') # Yellow warning badge
      end
    end

    context 'when trial has expired' do
      let(:user) { create(:user, subscription_status: 'trialing', trial_ends_at: 1.day.ago) }

      it 'shows expired trial status' do
        render

        expect(rendered).to have_content('Trial Expired')
        expect(rendered).to have_content('Your trial has ended')
        expect(rendered).to have_content('Upgrade now to regain access')
      end

      it 'does not show progress bar' do
        render

        expect(rendered).not_to have_content('Day')
      end
    end

    context 'when trial expires today' do
      let(:user) { create(:user, subscription_status: 'trialing', trial_ends_at: Time.current.end_of_day) }

      it 'shows expires today message' do
        render

        expect(rendered).to have_content('Your trial expires today')
      end
    end

    context 'when trial has many days remaining' do
      let(:user) { create(:user, subscription_status: 'trialing', trial_ends_at: 10.days.from_now) }

      it 'shows active trial message' do
        render

        expect(rendered).to have_content('Trial active (10 days remaining)')
        expect(rendered).to have_content('Trial Active')
        expect(rendered).to have_css('.bg-blue-100') # Blue active badge
      end
    end
  end

  describe 'non-trial users' do
    context 'when user has premium subscription' do
      let(:user) { create(:user, :premium, subscription_status: 'active') }

      before do
        allow(subscription_service).to receive(:user_has_active_subscription?).and_return(true)
        assign(:subscription_details, { amount: 2900, interval: 'month', currency: 'USD', source: 'stripe' })
      end

      it 'does not show trial status section' do
        render

        expect(rendered).not_to have_content('Premium Trial')
        expect(rendered).to have_content('Premium Plan')
      end
    end

    context 'when user has no active subscription' do
      let(:user) { create(:user, subscription_status: 'active') }

      it 'shows upgrade options' do
        render

        expect(rendered).to have_content('No Active Subscription')
        expect(rendered).to have_content('Upgrade to Premium')
      end
    end
  end
end