require 'rails_helper'

RSpec.describe 'PaymentSetupController JavaScript', type: :feature, js: true do
  let(:user) { create(:user, subscription_tier: 'basic') }
  let(:premium_user) { create(:user, subscription_tier: 'premium', stripe_enabled: true, stripe_publishable_key: 'pk_test_123', stripe_secret_key: 'sk_test_123') }
  let(:form_template) { create(:form_template, :with_payment_questions) }
  let(:payment_form) { create(:form, user: user, template: form_template) }

  before do
    sign_in user
  end

  describe 'Controller initialization and basic functionality' do
    it 'initializes with correct values and targets', :vcr do
      VCR.use_cassette('payment_setup_controller_init') do
        visit edit_form_path(payment_form)

        # Check that the controller is connected
        expect(page).to have_selector('[data-controller="payment-setup"]')
        
        # Check for required targets
        expect(page).to have_selector('[data-payment-setup-target="statusIndicator"]')
        expect(page).to have_selector('[data-payment-setup-target="setupChecklist"]')
      end
    end

    it 'calculates setup progress correctly' do
      visit edit_form_path(payment_form)

      # Test with no setup (basic user, no Stripe)
      progress = page.evaluate_script(<<~JS)
        const controller = document.querySelector('[data-controller="payment-setup"]');
        if (controller && controller.stimulus) {
          return controller.stimulus.calculateSetupProgress();
        }
        return null;
      JS

      expect(progress).to eq(0)
    end

    it 'identifies missing requirements correctly' do
      visit edit_form_path(payment_form)

      missing_requirements = page.evaluate_script(<<~JS)
        const controller = document.querySelector('[data-controller="payment-setup"]');
        if (controller && controller.stimulus) {
          return controller.stimulus.getMissingRequirements();
        }
        return null;
      JS

      expect(missing_requirements).to include('stripe_configuration')
      expect(missing_requirements).to include('premium_subscription')
    end
  end

  describe 'Status updates and UI changes' do
    it 'updates UI when setup status changes' do
      visit edit_form_path(payment_form)

      # Simulate Stripe configuration completion
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller="payment-setup"]');
        if (controller && controller.stimulus) {
          controller.stimulus.stripeConfiguredValue = true;
          controller.stimulus.updateSetupStatus();
        }
      JS

      # Check that progress updated
      progress = page.evaluate_script(<<~JS)
        const controller = document.querySelector('[data-controller="payment-setup"]');
        if (controller && controller.stimulus) {
          return controller.stimulus.calculateSetupProgress();
        }
        return 0;
      JS

      expect(progress).to eq(50)
    end

    it 'shows/hides setup checklist based on payment questions' do
      visit edit_form_path(payment_form)

      # Should show checklist for forms with payment questions
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller="payment-setup"]');
        if (controller && controller.stimulus) {
          controller.stimulus.hasPaymentQuestionsValue = true;
          controller.stimulus.updateSetupStatus();
        }
      JS

      expect(page).to have_selector('[data-payment-setup-target="setupChecklist"]', visible: true)

      # Should hide checklist for forms without payment questions
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller="payment-setup"]');
        if (controller && controller.stimulus) {
          controller.stimulus.hasPaymentQuestionsValue = false;
          controller.stimulus.updateSetupStatus();
        }
      JS

      expect(page).not_to have_selector('[data-payment-setup-target="setupChecklist"]', visible: true)
    end
  end

  describe 'Event tracking' do
    it 'tracks setup events when actions are initiated' do
      visit edit_form_path(payment_form)

      # Mock analytics
      page.execute_script(<<~JS)
        window.trackedEvents = [];
        window.analytics = {
          track: function(event, data) {
            window.trackedEvents.push({event: event, data: data});
          }
        };
      JS

      # Trigger setup event
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller="payment-setup"]');
        if (controller && controller.stimulus) {
          controller.stimulus.trackSetupEvent('test_event', {test: 'data'});
        }
      JS

      # Check that event was tracked
      tracked_events = page.evaluate_script('window.trackedEvents')
      expect(tracked_events).to include(hash_including(
        'event' => 'payment_setup_interaction',
        'data' => hash_including('event_type' => 'test_event', 'test' => 'data')
      ))
    end
  end

  describe 'Error handling' do
    it 'handles missing targets gracefully' do
      visit edit_form_path(payment_form)

      # Remove targets and try to update
      page.execute_script(<<~JS)
        const targets = document.querySelectorAll('[data-payment-setup-target]');
        targets.forEach(target => target.remove());
        
        const controller = document.querySelector('[data-controller="payment-setup"]');
        if (controller && controller.stimulus) {
          controller.stimulus.updateSetupStatus();
        }
      JS

      # Should not throw errors
      expect(page).not_to have_text('Error')
    end

    it 'handles API errors during status polling' do
      visit edit_form_path(payment_form)

      # Mock failed fetch
      page.execute_script(<<~JS)
        window.originalFetch = window.fetch;
        window.fetch = function() {
          return Promise.reject(new Error('Network error'));
        };
        
        const controller = document.querySelector('[data-controller="payment-setup"]');
        if (controller && controller.stimulus) {
          controller.stimulus.checkSetupProgress();
        }
      JS

      # Should handle error gracefully
      expect(page).not_to have_text('Network error')
    end
  end

  describe 'Modal functionality' do
    it 'creates and shows setup modal with correct content' do
      visit edit_form_path(payment_form)

      # Trigger modal creation
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller="payment-setup"]');
        if (controller && controller.stimulus) {
          controller.stimulus.showCompleteSetupModal();
        }
      JS

      # Check modal content
      expect(page).to have_text('Complete Payment Setup')
      expect(page).to have_text('Configure Stripe')
      expect(page).to have_text('Upgrade to Premium')
    end

    it 'removes modal when close button is clicked' do
      visit edit_form_path(payment_form)

      # Create modal
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller="payment-setup"]');
        if (controller && controller.stimulus) {
          controller.stimulus.showCompleteSetupModal();
        }
      JS

      expect(page).to have_text('Complete Payment Setup')

      # Click close button
      click_button 'Close'

      expect(page).not_to have_text('Complete Payment Setup')
    end
  end

  describe 'Polling functionality' do
    it 'starts and stops polling correctly' do
      visit edit_form_path(payment_form)

      # Check that polling starts for incomplete setup
      polling_active = page.evaluate_script(<<~JS)
        const controller = document.querySelector('[data-controller="payment-setup"]');
        if (controller && controller.stimulus) {
          controller.stimulus.setupPolling();
          return controller.stimulus.pollingInterval !== null;
        }
        return false;
      JS

      expect(polling_active).to be true

      # Check that polling stops
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller="payment-setup"]');
        if (controller && controller.stimulus) {
          controller.stimulus.stopPolling();
        }
      JS

      polling_stopped = page.evaluate_script(<<~JS)
        const controller = document.querySelector('[data-controller="payment-setup"]');
        if (controller && controller.stimulus) {
          return controller.stimulus.pollingInterval === null;
        }
        return true;
      JS

      expect(polling_stopped).to be true
    end
  end

  describe 'Value updates' do
    it 'updates controller values from API response' do
      visit edit_form_path(payment_form)

      # Simulate API response
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller="payment-setup"]');
        if (controller && controller.stimulus) {
          const setupStatus = {
            stripe_configured: true,
            premium_subscription: false
          };
          controller.stimulus.updateSetupValues(setupStatus);
        }
      JS

      # Check values were updated
      stripe_configured = page.evaluate_script(<<~JS)
        const controller = document.querySelector('[data-controller="payment-setup"]');
        return controller && controller.stimulus ? controller.stimulus.stripeConfiguredValue : false;
      JS

      premium_subscription = page.evaluate_script(<<~JS)
        const controller = document.querySelector('[data-controller="payment-setup"]');
        return controller && controller.stimulus ? controller.stimulus.isPremiumValue : false;
      JS

      expect(stripe_configured).to be true
      expect(premium_subscription).to be false
    end
  end
end