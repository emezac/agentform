require 'rails_helper'

RSpec.describe 'Trial Subscription Management Display', type: :system do
  let(:user) { create(:user, :trialing_user) }
  
  before do
    sign_in user
  end

  describe 'trial status display' do
    context 'when user has active trial' do
      before do
        user.update!(
          subscription_status: 'trialing',
          trial_ends_at: 5.days.from_now,
          created_at: (TrialConfig.trial_period_days - 5).days.ago
        )
      end

      it 'displays correct trial information' do
        visit subscription_management_path
        
        expect(page).to have_content('5 days left in your trial')
        expect(page).to have_content('Trial Active')
        expect(page).to have_content('Day 10 of 14')
        expect(page).to have_content('Enjoy full access to all features during your trial period')
      end
    end

    context 'when trial expires soon (3 days or less)' do
      before do
        user.update!(
          subscription_status: 'trialing',
          trial_ends_at: 2.days.from_now,
          created_at: (TrialConfig.trial_period_days - 2).days.ago
        )
      end

      it 'displays urgent warning message' do
        visit subscription_management_path
        
        expect(page).to have_content('Your trial expires in 2 days')
        expect(page).to have_content('⚠️ Your trial expires very soon!')
        expect(page).to have_content('Trial (Expires Soon)')
      end
    end

    context 'when trial has expired' do
      before do
        user.update!(
          subscription_status: 'trialing',
          trial_ends_at: 2.days.ago,
          created_at: (TrialConfig.trial_period_days + 2).days.ago
        )
      end

      it 'displays expired trial message' do
        visit subscription_management_path
        
        expect(page).to have_content('Your trial has expired')
        expect(page).to have_content('Trial Expired')
      end
    end
  end
end