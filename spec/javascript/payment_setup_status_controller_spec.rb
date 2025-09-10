# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PaymentSetupStatusController', type: :system, js: true do
  let(:user) { create(:user, subscription_tier: 'freemium') }
  let(:premium_user) { create(:user, subscription_tier: 'premium') }
  let(:form) { create(:form, user: user) }
  let(:form_with_payments) { create(:form, user: user) }

  before do
    create(:form_question, form: form_with_payments, question_type: 'payment', title: 'Payment Question')
  end

  describe 'Controller initialization' do
    it 'connects successfully and initializes values' do
      sign_in user
      visit edit_form_path(form_with_payments)

      # Check that controller is connected
      controller_connected = page.evaluate_script(<<~JS)
        const element = document.querySelector('[data-controller*="payment-setup-status"]');
        const controller = element._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        controller !== undefined;
      JS

      expect(controller_connected).to be true

      # Check that values are properly initialized
      values = page.evaluate_script(<<~JS)
        const element = document.querySelector('[data-controller*="payment-setup-status"]');
        const controller = element._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        ({
          formId: controller.formIdValue,
          hasPaymentQuestions: controller.hasPaymentQuestionsValue,
          stripeConfigured: controller.stripeConfiguredValue,
          isPremium: controller.isPremiumValue,
          setupComplete: controller.setupCompleteValue,
          completionPercentage: controller.completionPercentageValue
        });
      JS

      expect(values['formId']).to eq(form_with_payments.id.to_s)
      expect(values['hasPaymentQuestions']).to be true
      expect(values['stripeConfigured']).to be false
      expect(values['isPremium']).to be false
      expect(values['setupComplete']).to be false
      expect(values['completionPercentage']).to eq(0)
    end
  end

  describe 'Status display updates' do
    it 'shows payment status elements when form has payment questions' do
      sign_in user
      visit edit_form_path(form_with_payments)

      expect(page).to have_css('[data-payment-setup-status-target="statusIndicator"]')
      expect(page).to have_css('[data-payment-setup-status-target="notificationBar"]')
    end

    it 'hides payment status elements when form has no payment questions' do
      sign_in user
      visit edit_form_path(form)

      expect(page).not_to have_css('[data-payment-setup-status-target="statusIndicator"]')
      expect(page).not_to have_css('[data-payment-setup-status-target="notificationBar"]')
    end

    it 'updates progress bar correctly' do
      sign_in user
      visit edit_form_path(form_with_payments)

      # Test 0% progress
      progress_width = page.evaluate_script(<<~JS)
        const progressBar = document.querySelector('[data-payment-setup-status-target="progressBar"]');
        progressBar.style.width;
      JS
      expect(progress_width).to eq('0%')

      # Update to 50% and test
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller*="payment-setup-status"]')
          ._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        controller.completionPercentageValue = 50;
        controller.updateProgressBar();
      JS

      progress_width = page.evaluate_script(<<~JS)
        const progressBar = document.querySelector('[data-payment-setup-status-target="progressBar"]');
        progressBar.style.width;
      JS
      expect(progress_width).to eq('50%')

      # Check progress text
      expect(page).to have_content('50% Complete')
    end

    it 'updates progress bar color based on completion percentage' do
      sign_in user
      visit edit_form_path(form_with_payments)

      # Test red color for low completion
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller*="payment-setup-status"]')
          ._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        controller.completionPercentageValue = 25;
        controller.updateProgressBar();
      JS

      progress_classes = page.evaluate_script(<<~JS)
        const progressBar = document.querySelector('[data-payment-setup-status-target="progressBar"]');
        progressBar.className;
      JS
      expect(progress_classes).to include('bg-red-500')

      # Test yellow color for medium completion
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller*="payment-setup-status"]')
          ._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        controller.completionPercentageValue = 75;
        controller.updateProgressBar();
      JS

      progress_classes = page.evaluate_script(<<~JS)
        const progressBar = document.querySelector('[data-payment-setup-status-target="progressBar"]');
        progressBar.className;
      JS
      expect(progress_classes).to include('bg-yellow-500')

      # Test green color for high completion
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller*="payment-setup-status"]')
          ._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        controller.completionPercentageValue = 100;
        controller.updateProgressBar();
      JS

      progress_classes = page.evaluate_script(<<~JS)
        const progressBar = document.querySelector('[data-payment-setup-status-target="progressBar"]');
        progressBar.className;
      JS
      expect(progress_classes).to include('bg-green-500')
    end
  end

  describe 'Modal functionality' do
    it 'opens setup modal when clicking action button' do
      sign_in user
      visit edit_form_path(form_with_payments)

      click_button 'Complete Setup'

      modal_visible = page.evaluate_script(<<~JS)
        const modal = document.querySelector('[data-payment-setup-status-target="setupModal"]');
        !modal.classList.contains('hidden');
      JS

      expect(modal_visible).to be true
      expect(page).to have_content('Complete Payment Setup')
    end

    it 'closes setup modal when clicking close button' do
      sign_in user
      visit edit_form_path(form_with_payments)

      # Open modal
      click_button 'Complete Setup'
      
      # Close modal
      within('[data-payment-setup-status-target="setupModal"]') do
        find('button', text: 'Close').click
      end

      modal_hidden = page.evaluate_script(<<~JS)
        const modal = document.querySelector('[data-payment-setup-status-target="setupModal"]');
        modal.classList.contains('hidden');
      JS

      expect(modal_hidden).to be true
    end

    it 'populates requirements list in modal' do
      sign_in user
      visit edit_form_path(form_with_payments)

      click_button 'Complete Setup'

      within('[data-payment-setup-status-target="setupModal"]') do
        expect(page).to have_content('Configure Stripe payment processing')
        expect(page).to have_content('Upgrade to Premium subscription')
        expect(page).to have_link('Configure Stripe')
        expect(page).to have_link('Upgrade Plan')
      end
    end
  end

  describe 'API integration' do
    it 'checks setup status via API', :js do
      sign_in user
      visit edit_form_path(form_with_payments)

      # Mock successful API response
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller*="payment-setup-status"]')
          ._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        
        // Override fetch to return mock data
        const originalFetch = window.fetch;
        window.fetch = function(url, options) {
          if (url.includes('payment_setup_status')) {
            return Promise.resolve({
              ok: true,
              json: () => Promise.resolve({
                stripe_configured: true,
                premium_subscription: true,
                setup_complete: true,
                completion_percentage: 100
              })
            });
          }
          return originalFetch(url, options);
        };
        
        // Trigger status check
        controller.checkSetupStatus();
      JS

      sleep 1 # Wait for async operation

      # Check that status was updated
      within('[data-payment-setup-status-target="statusIndicator"]') do
        expect(page).to have_content('Payment Ready')
      end
    end

    it 'handles API errors gracefully' do
      sign_in user
      visit edit_form_path(form_with_payments)

      # Mock API error
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller*="payment-setup-status"]')
          ._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        
        // Override fetch to return error
        window.fetch = function(url, options) {
          if (url.includes('payment_setup_status')) {
            return Promise.reject(new Error('Network error'));
          }
          return originalFetch(url, options);
        };
        
        // Trigger status check
        controller.checkSetupStatus();
      JS

      sleep 1 # Wait for async operation

      # Status should remain unchanged (no errors thrown)
      within('[data-payment-setup-status-target="statusIndicator"]') do
        expect(page).to have_content('Setup Required')
      end
    end
  end

  describe 'Real-time updates' do
    it 'shows toast notification when status changes' do
      sign_in user
      visit edit_form_path(form_with_payments)

      # Simulate status change to complete
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller*="payment-setup-status"]')
          ._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        
        controller.updateStatusFromAPI({
          stripe_configured: true,
          premium_subscription: true,
          setup_complete: true,
          completion_percentage: 100
        });
      JS

      # Should show success toast
      expect(page).to have_content('Payment setup completed!')
    end

    it 'updates status when payment questions are added' do
      sign_in user
      visit edit_form_path(form)

      # Initially no payment status
      expect(page).not_to have_css('[data-payment-setup-status-target="statusIndicator"]')

      # Simulate payment question added
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller*="payment-setup-status"]')
          ._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        controller.onPaymentQuestionAdded();
      JS

      # Should now show payment status
      expect(page).to have_css('[data-payment-setup-status-target="statusIndicator"]')
    end

    it 'updates status when payment questions are removed' do
      sign_in user
      visit edit_form_path(form_with_payments)

      # Initially has payment status
      expect(page).to have_css('[data-payment-setup-status-target="statusIndicator"]')

      # Mock API response for no payment questions
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller*="payment-setup-status"]')
          ._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        
        // Override fetch to return no payment questions
        window.fetch = function(url, options) {
          if (url.includes('has_payment_questions')) {
            return Promise.resolve({
              ok: true,
              json: () => Promise.resolve({
                has_payment_questions: false,
                payment_questions_count: 0
              })
            });
          }
          return originalFetch(url, options);
        };
        
        controller.onPaymentQuestionRemoved();
      JS

      sleep 1 # Wait for async operation

      # Should hide payment status
      expect(page).not_to have_css('[data-payment-setup-status-target="statusIndicator"]:not(.hidden)')
    end
  end

  describe 'Periodic status checking' do
    it 'starts periodic checking on connect' do
      sign_in user
      visit edit_form_path(form_with_payments)

      # Check that interval is set
      has_interval = page.evaluate_script(<<~JS)
        const controller = document.querySelector('[data-controller*="payment-setup-status"]')
          ._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        controller.checkInterval !== undefined;
      JS

      expect(has_interval).to be true
    end

    it 'clears interval on disconnect' do
      sign_in user
      visit edit_form_path(form_with_payments)

      # Simulate disconnect
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller*="payment-setup-status"]')
          ._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        controller.disconnect();
      JS

      # Check that interval is cleared
      interval_cleared = page.evaluate_script(<<~JS)
        const controller = document.querySelector('[data-controller*="payment-setup-status"]')
          ._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        controller.checkInterval === undefined;
      JS

      expect(interval_cleared).to be true
    end
  end

  describe 'Missing requirements detection' do
    it 'correctly identifies missing Stripe configuration' do
      sign_in user
      visit edit_form_path(form_with_payments)

      missing_requirements = page.evaluate_script(<<~JS)
        const controller = document.querySelector('[data-controller*="payment-setup-status"]')
          ._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        controller.getMissingRequirements();
      JS

      expect(missing_requirements).to include('Configure Stripe payment processing')
    end

    it 'correctly identifies missing Premium subscription' do
      sign_in user
      visit edit_form_path(form_with_payments)

      missing_requirements = page.evaluate_script(<<~JS)
        const controller = document.querySelector('[data-controller*="payment-setup-status"]')
          ._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        controller.getMissingRequirements();
      JS

      expect(missing_requirements).to include('Upgrade to Premium subscription')
    end

    it 'returns empty array when setup is complete' do
      premium_user.update!(
        stripe_enabled: true,
        stripe_publishable_key: 'pk_test_123',
        stripe_secret_key: 'sk_test_123'
      )
      premium_form = create(:form, user: premium_user)
      create(:form_question, form: premium_form, question_type: 'payment', title: 'Payment Question')

      sign_in premium_user
      visit edit_form_path(premium_form)

      missing_requirements = page.evaluate_script(<<~JS)
        const controller = document.querySelector('[data-controller*="payment-setup-status"]')
          ._stimulusControllers.find(c => c.identifier === 'payment-setup-status');
        controller.getMissingRequirements();
      JS

      expect(missing_requirements).to be_empty
    end
  end
end