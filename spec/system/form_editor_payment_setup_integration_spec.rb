# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Form Editor Payment Setup Integration', type: :system, js: true do
  let(:user) { create(:user, subscription_tier: 'freemium') }
  let(:premium_user) { create(:user, subscription_tier: 'premium') }
  let(:form) { create(:form, user: user) }
  let(:form_with_payments) { create(:form, user: user) }
  let(:premium_form) { create(:form, user: premium_user) }

  before do
    # Create a payment question for forms that need it
    create(:form_question, form: form_with_payments, question_type: 'payment', title: 'Payment Question')
  end

  describe 'Payment status indicator in form header' do
    context 'when form has no payment questions' do
      it 'does not show payment status indicator' do
        sign_in user
        visit edit_form_path(form)

        expect(page).not_to have_css('[data-payment-setup-status-target="statusIndicator"]')
      end
    end

    context 'when form has payment questions but user setup is incomplete' do
      it 'shows setup required indicator' do
        sign_in user
        visit edit_form_path(form_with_payments)

        within('[data-payment-setup-status-target="statusIndicator"]') do
          expect(page).to have_content('Setup Required')
          expect(page).to have_css('.bg-amber-100')
        end
      end
    end

    context 'when form has payment questions and user setup is complete' do
      before do
        premium_user.update!(
          stripe_enabled: true,
          stripe_publishable_key: 'pk_test_123',
          stripe_secret_key: 'sk_test_123'
        )
        create(:form_question, form: premium_form, question_type: 'payment', title: 'Payment Question')
      end

      it 'shows payment ready indicator' do
        sign_in premium_user
        visit edit_form_path(premium_form)

        within('[data-payment-setup-status-target="statusIndicator"]') do
          expect(page).to have_content('Payment Ready')
          expect(page).to have_css('.bg-green-100')
        end
      end
    end
  end

  describe 'Payment setup notification bar' do
    context 'when form has payment questions but setup is incomplete' do
      it 'shows notification bar with setup requirements' do
        sign_in user
        visit edit_form_path(form_with_payments)

        within('[data-payment-setup-status-target="notificationBar"]') do
          expect(page).to have_content('Payment setup required')
          expect(page).to have_content('Configure Stripe payment processing')
          expect(page).to have_content('Upgrade to Premium subscription')
          expect(page).to have_button('Complete Setup')
        end
      end

      it 'shows progress bar with correct percentage' do
        sign_in user
        visit edit_form_path(form_with_payments)

        within('[data-payment-setup-status-target="notificationBar"]') do
          expect(page).to have_css('[data-payment-setup-status-target="progressBar"]')
          expect(page).to have_content('0% Complete')
        end
      end
    end

    context 'when setup is partially complete' do
      before do
        user.update!(subscription_tier: 'premium')
      end

      it 'shows updated progress' do
        sign_in user
        visit edit_form_path(form_with_payments)

        within('[data-payment-setup-status-target="notificationBar"]') do
          expect(page).to have_content('50% Complete')
          expect(page).to have_content('Configure Stripe payment processing')
          expect(page).not_to have_content('Upgrade to Premium subscription')
        end
      end
    end

    context 'when setup is complete' do
      before do
        premium_user.update!(
          stripe_enabled: true,
          stripe_publishable_key: 'pk_test_123',
          stripe_secret_key: 'sk_test_123'
        )
        create(:form_question, form: premium_form, question_type: 'payment', title: 'Payment Question')
      end

      it 'shows success notification' do
        sign_in premium_user
        visit edit_form_path(premium_form)

        within('[data-payment-setup-status-target="notificationBar"]') do
          expect(page).to have_content('Payment setup complete!')
          expect(page).to have_css('.bg-green-50')
        end
      end
    end
  end

  describe 'Payment setup modal' do
    it 'opens setup modal when clicking complete setup button' do
      sign_in user
      visit edit_form_path(form_with_payments)

      click_button 'Complete Setup'

      within('[data-payment-setup-status-target="setupModal"]') do
        expect(page).to have_content('Complete Payment Setup')
        expect(page).to have_content('Configure Stripe payment processing')
        expect(page).to have_content('Upgrade to Premium subscription')
        expect(page).to have_link('Configure Stripe')
        expect(page).to have_link('Upgrade Plan')
      end
    end

    it 'closes modal when clicking close button' do
      sign_in user
      visit edit_form_path(form_with_payments)

      click_button 'Complete Setup'
      expect(page).to have_css('[data-payment-setup-status-target="setupModal"]:not(.hidden)')

      within('[data-payment-setup-status-target="setupModal"]') do
        find('button', text: 'Close').click
      end

      expect(page).to have_css('[data-payment-setup-status-target="setupModal"].hidden')
    end
  end

  describe 'Real-time status updates' do
    it 'updates status when payment questions are added', :js do
      sign_in user
      visit edit_form_path(form)

      # Initially no payment status should be shown
      expect(page).not_to have_css('[data-payment-setup-status-target="statusIndicator"]')

      # Add a payment question (this would normally be done through the form builder)
      # For this test, we'll simulate the API call
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller*="payment-setup-status"]')
          ._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        controller.hasPaymentQuestionsValue = true;
        controller.updateStatusDisplay();
      JS

      # Now payment status should be visible
      expect(page).to have_css('[data-payment-setup-status-target="statusIndicator"]')
      expect(page).to have_content('Setup Required')
    end

    it 'updates status when setup is completed in another tab', :js do
      sign_in user
      visit edit_form_path(form_with_payments)

      # Mock the API response for setup completion
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller*="payment-setup-status"]')
          ._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        
        // Simulate setup completion
        controller.updateStatusFromAPI({
          stripe_configured: true,
          premium_subscription: true,
          setup_complete: true,
          completion_percentage: 100
        });
      JS

      # Status should update to show completion
      within('[data-payment-setup-status-target="statusIndicator"]') do
        expect(page).to have_content('Payment Ready')
      end

      within('[data-payment-setup-status-target="notificationBar"]') do
        expect(page).to have_content('Payment setup complete!')
      end
    end
  end

  describe 'Form publishing with payment validation' do
    context 'when form has payment questions but setup is incomplete' do
      it 'prevents publishing and shows payment setup error' do
        sign_in user
        visit edit_form_path(form_with_payments)

        click_button 'Publish'

        expect(page).to have_content('Payment configuration is required')
        expect(form_with_payments.reload.status).to eq('draft')
      end
    end

    context 'when form has payment questions and setup is complete' do
      before do
        premium_user.update!(
          stripe_enabled: true,
          stripe_publishable_key: 'pk_test_123',
          stripe_secret_key: 'sk_test_123'
        )
        create(:form_question, form: premium_form, question_type: 'payment', title: 'Payment Question')
      end

      it 'allows publishing successfully' do
        sign_in premium_user
        visit edit_form_path(premium_form)

        click_button 'Publish'

        expect(page).to have_content('Form has been published successfully')
        expect(premium_form.reload.status).to eq('published')
      end
    end
  end

  describe 'API endpoints' do
    it 'returns payment setup status via API' do
      sign_in user
      visit edit_form_path(form_with_payments)

      # Test the API endpoint directly
      page.execute_script(<<~JS)
        fetch(`/forms/${#{form_with_payments.id}}/payment_setup_status`, {
          headers: { 'Accept': 'application/json' }
        })
        .then(response => response.json())
        .then(data => {
          window.testApiResponse = data;
        });
      JS

      sleep 1 # Wait for API call

      api_response = page.evaluate_script('window.testApiResponse')
      expect(api_response['has_payment_questions']).to be true
      expect(api_response['stripe_configured']).to be false
      expect(api_response['premium_subscription']).to be false
      expect(api_response['setup_complete']).to be false
      expect(api_response['completion_percentage']).to eq(0)
    end

    it 'returns payment questions status via API' do
      sign_in user
      visit edit_form_path(form_with_payments)

      page.execute_script(<<~JS)
        fetch(`/forms/${#{form_with_payments.id}}/has_payment_questions`, {
          headers: { 'Accept': 'application/json' }
        })
        .then(response => response.json())
        .then(data => {
          window.testPaymentQuestionsResponse = data;
        });
      JS

      sleep 1 # Wait for API call

      api_response = page.evaluate_script('window.testPaymentQuestionsResponse')
      expect(api_response['has_payment_questions']).to be true
      expect(api_response['payment_questions_count']).to eq(1)
    end
  end

  describe 'Progress tracking' do
    it 'shows correct completion percentage for different setup states' do
      # Test 0% completion (no setup)
      sign_in user
      visit edit_form_path(form_with_payments)
      
      within('[data-payment-setup-status-target="notificationBar"]') do
        expect(page).to have_content('0% Complete')
      end

      # Test 50% completion (premium but no Stripe)
      user.update!(subscription_tier: 'premium')
      visit edit_form_path(form_with_payments)
      
      within('[data-payment-setup-status-target="notificationBar"]') do
        expect(page).to have_content('50% Complete')
      end
    end

    it 'updates progress bar color based on completion percentage' do
      sign_in user
      visit edit_form_path(form_with_payments)

      # Should be red for 0% completion
      progress_bar = find('[data-payment-setup-status-target="progressBar"]')
      expect(progress_bar[:class]).to include('bg-red-500')

      # Update to 50% and check color
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller*="payment-setup-status"]')
          ._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        controller.completionPercentageValue = 50;
        controller.updateProgressBar();
      JS

      expect(progress_bar[:class]).to include('bg-yellow-500')

      # Update to 100% and check color
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller*="payment-setup-status"]')
          ._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        controller.completionPercentageValue = 100;
        controller.updateProgressBar();
      JS

      expect(progress_bar[:class]).to include('bg-green-500')
    end
  end
end