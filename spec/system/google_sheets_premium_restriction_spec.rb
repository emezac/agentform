require 'rails_helper'

RSpec.describe 'Google Sheets Premium Restriction', type: :system do
  let(:form) { create(:form, user: user) }

  context 'with premium user' do
    let(:user) { create(:user, subscription_tier: 'premium') }

    before do
      sign_in user
      visit edit_form_path(form)
    end

    it 'shows full Google Sheets functionality' do
      expect(page).to have_content('Google Sheets')
      expect(page).to have_content('Auto-export responses')
      expect(page).not_to have_content('Premium Feature')
      expect(page).not_to have_content('Upgrade to Premium')
    end

    it 'shows setup options when not connected' do
      expect(page).to have_content('Export responses to Google Sheets')
      expect(page).to have_button('Test')
      expect(page).to have_button('Connect')
    end
  end

  context 'with admin user' do
    let(:user) { create(:user, role: 'admin', subscription_tier: 'basic') }

    before do
      sign_in user
      visit edit_form_path(form)
    end

    it 'shows full Google Sheets functionality' do
      expect(page).to have_content('Google Sheets')
      expect(page).to have_content('Auto-export responses')
      expect(page).not_to have_content('Premium Feature')
      expect(page).not_to have_content('Upgrade to Premium')
    end
  end

  context 'with basic user' do
    let(:user) { create(:user, subscription_tier: 'basic', role: 'user') }

    before do
      sign_in user
      visit edit_form_path(form)
    end

    it 'shows premium upgrade prompt instead of Google Sheets functionality' do
      expect(page).to have_content('Premium Feature')
      expect(page).to have_content('Google Sheets integration is available with Premium subscription')
      expect(page).to have_link('Upgrade to Premium')
      expect(page).to have_content('Starting at $29/month')
    end

    it 'does not show Google Sheets setup options' do
      expect(page).not_to have_button('Test')
      expect(page).not_to have_button('Connect')
      expect(page).not_to have_content('Auto-sync')
      expect(page).not_to have_content('Export existing responses')
    end

    it 'upgrade link points to subscription management' do
      click_link 'Upgrade to Premium'
      expect(current_path).to eq(subscription_management_path)
    end
  end

  context 'with basic user (additional test)' do
    let(:user) { create(:user, subscription_tier: 'basic', role: 'user') }

    before do
      sign_in user
      visit edit_form_path(form)
    end

    it 'shows premium upgrade prompt consistently' do
      expect(page).to have_content('Premium Feature')
      expect(page).to have_content('Google Sheets integration is available with Premium subscription')
      expect(page).to have_link('Upgrade to Premium')
    end

    it 'does not show Google Sheets functionality' do
      expect(page).not_to have_button('Test')
      expect(page).not_to have_button('Connect')
      expect(page).not_to have_content('Auto-sync')
    end
  end
end