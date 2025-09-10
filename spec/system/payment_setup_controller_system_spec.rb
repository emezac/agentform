require 'rails_helper'

RSpec.describe 'PaymentSetupController System Tests', type: :system, js: true do
  let(:user) { create(:user, subscription_tier: 'basic') }
  let(:premium_user) { create(:user, subscription_tier: 'premium', stripe_enabled: true, stripe_publishable_key: 'pk_test_123', stripe_secret_key: 'sk_test_123') }
  let(:form_template) { create(:form_template, :with_payment_questions) }
  let(:payment_form) { create(:form, user: user, template: form_template) }

  before do
    sign_in user
  end

  describe 'Payment setup status display' do
    context 'when user has no payment setup' do
      it 'shows incomplete setup status and required actions' do
        visit edit_form_path(payment_form)

        # Should show setup checklist
        expect(page).to have_selector('[data-payment-setup-target="setupChecklist"]', visible: true)
        
        # Should show status indicator with incomplete status
        within('[data-payment-setup-target="statusIndicator"]') do
          expect(page).to have_text('Setup 0% complete')
          expect(page).to have_selector('.status-icon svg.text-amber-600')
        end

        # Should show requirement items as incomplete
        within('[data-payment-setup-target="requirementItem"][data-requirement="stripe_configuration"]') do
          expect(page).to have_unchecked_field(class: 'requirement-checkbox')
          expect(page).to have_selector('.requirement-action', visible: true)
        end

        within('[data-payment-setup-target="requirementItem"][data-requirement="premium_subscription"]') do
          expect(page).to have_unchecked_field(class: 'requirement-checkbox')
          expect(page).to have_selector('.requirement-action', visible: true)
        end
      end
    end

    context 'when user has partial setup (Stripe only)' do
      before do
        user.update!(stripe_enabled: true, stripe_publishable_key: 'pk_test_123', stripe_secret_key: 'sk_test_123')
      end

      it 'shows partial setup status' do
        visit edit_form_path(payment_form)

        # Should show 50% completion
        within('[data-payment-setup-target="statusIndicator"]') do
          expect(page).to have_text('Setup 50% complete')
        end

        # Stripe should be complete, Premium should be incomplete
        within('[data-payment-setup-target="requirementItem"][data-requirement="stripe_configuration"]') do
          expect(page).to have_checked_field(class: 'requirement-checkbox')
          expect(page).to have_selector('.requirement-action', visible: false)
        end

        within('[data-payment-setup-target="requirementItem"][data-requirement="premium_subscription"]') do
          expect(page).to have_unchecked_field(class: 'requirement-checkbox')
          expect(page).to have_selector('.requirement-action', visible: true)
        end
      end
    end

    context 'when user has complete setup' do
      before do
        sign_out user
        sign_in premium_user
        payment_form.update!(user: premium_user)
      end

      it 'shows complete setup status and hides checklist' do
        visit edit_form_path(payment_form)

        # Should show 100% completion
        within('[data-payment-setup-target="statusIndicator"]') do
          expect(page).to have_text('Payment setup complete')
          expect(page).to have_selector('.status-icon svg.text-green-600')
        end

        # All requirements should be complete
        within('[data-payment-setup-target="requirementItem"][data-requirement="stripe_configuration"]') do
          expect(page).to have_checked_field(class: 'requirement-checkbox')
          expect(page).to have_selector('.requirement-action', visible: false)
        end

        within('[data-payment-setup-target="requirementItem"][data-requirement="premium_subscription"]') do
          expect(page).to have_checked_field(class: 'requirement-checkbox')
          expect(page).to have_selector('.requirement-action', visible: false)
        end
      end
    end
  end

  describe 'Setup action initiation' do
    it 'opens Stripe configuration in new tab when clicking Stripe setup action' do
      visit edit_form_path(payment_form)

      # Mock window.open to track the call
      page.execute_script(<<~JS)
        window.openedUrls = [];
        window.originalOpen = window.open;
        window.open = function(url, target, features) {
          window.openedUrls.push({url: url, target: target, features: features});
          return { focus: function() {} };
        };
      JS

      # Click Stripe setup action
      within('[data-payment-setup-target="requirementItem"][data-requirement="stripe_configuration"]') do
        click_button 'Configure'
      end

      # Verify new tab was opened
      opened_urls = page.evaluate_script('window.openedUrls')
      expect(opened_urls).to include(hash_including('url' => '/stripe_settings', 'target' => '_blank'))
    end

    it 'opens subscription management in new tab when clicking Premium upgrade action' do
      visit edit_form_path(payment_form)

      # Mock window.open
      page.execute_script(<<~JS)
        window.openedUrls = [];
        window.open = function(url, target, features) {
          window.openedUrls.push({url: url, target: target, features: features});
          return { focus: function() {} };
        };
      JS

      # Click Premium upgrade action
      within('[data-payment-setup-target="requirementItem"][data-requirement="premium_subscription"]') do
        click_button 'Upgrade'
      end

      # Verify new tab was opened
      opened_urls = page.evaluate_script('window.openedUrls')
      expect(opened_urls).to include(hash_including('url' => '/subscription_management', 'target' => '_blank'))
    end

    it 'shows complete setup modal when clicking complete setup button' do
      visit edit_form_path(payment_form)

      # Click complete setup button
      click_button 'Complete Setup', match: :first

      # Should show modal with setup options
      expect(page).to have_text('Complete Payment Setup')
      expect(page).to have_text('Configure Stripe')
      expect(page).to have_text('Upgrade to Premium')

      # Should have action buttons in modal
      expect(page).to have_button('Configure', count: 2) # One in modal, one in checklist
      expect(page).to have_button('Upgrade', count: 2)   # One in modal, one in checklist
    end
  end

  describe 'Real-time status updates' do
    it 'polls for setup progress and updates UI' do
      # Mock the API endpoint
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      
      # Create a route for the status endpoint
      Rails.application.routes.draw do
        namespace :api do
          namespace :v1 do
            get 'payment_setup/status', to: proc { |env|
              [200, {'Content-Type' => 'application/json'}, [
                {
                  success: true,
                  setup_status: {
                    stripe_configured: true,
                    premium_subscription: false,
                    can_accept_payments: false,
                    setup_completion_percentage: 50
                  }
                }.to_json
              ]]
            }
          end
        end
      end

      visit edit_form_path(payment_form)

      # Wait for initial load
      expect(page).to have_text('Setup 0% complete')

      # Simulate setup progress by updating the user
      user.update!(stripe_enabled: true, stripe_publishable_key: 'pk_test_123', stripe_secret_key: 'sk_test_123')

      # Wait for polling to update the UI (controller polls every 5 seconds)
      sleep 6

      # Should show updated status
      expect(page).to have_text('Setup 50% complete')
    end
  end

  describe 'Action button state management' do
    it 'disables publish button when setup is incomplete' do
      visit edit_form_path(payment_form)

      # Publish button should be disabled
      publish_button = find('[data-payment-setup-target="actionButton"][data-button-type="publish-form"]')
      expect(publish_button).to be_disabled
      expect(publish_button[:class]).to include('bg-gray-200')
    end

    it 'enables publish button when setup is complete' do
      sign_out user
      sign_in premium_user
      payment_form.update!(user: premium_user)

      visit edit_form_path(payment_form)

      # Publish button should be enabled
      publish_button = find('[data-payment-setup-target="actionButton"][data-button-type="publish-form"]')
      expect(publish_button).not_to be_disabled
      expect(publish_button[:class]).to include('bg-indigo-600')
    end

    it 'hides complete setup button when setup is finished' do
      sign_out user
      sign_in premium_user
      payment_form.update!(user: premium_user)

      visit edit_form_path(payment_form)

      # Complete setup button should be hidden
      expect(page).not_to have_selector('[data-payment-setup-target="actionButton"][data-button-type="complete-setup"]', visible: true)
    end
  end

  describe 'Animation and visual feedback' do
    it 'animates checklist appearance' do
      visit edit_form_path(payment_form)

      # Checklist should be visible and animated
      checklist = find('[data-payment-setup-target="setupChecklist"]')
      expect(checklist).to be_visible

      # Should have transition styles applied
      expect(checklist[:style]).to include('transition')
    end

    it 'shows completion animation when requirements are met' do
      visit edit_form_path(payment_form)

      # Simulate completing Stripe setup
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller="payment-setup"]');
        const stimulusController = controller.stimulus;
        if (stimulusController) {
          stimulusController.stripeConfiguredValue = true;
          stimulusController.updateSetupStatus();
        }
      JS

      # Should show animation on completed requirement
      stripe_item = find('[data-payment-setup-target="requirementItem"][data-requirement="stripe_configuration"]')
      expect(stripe_item[:class]).to include('animate-pulse')
    end
  end

  describe 'Event tracking and analytics' do
    it 'tracks setup initiation events' do
      visit edit_form_path(payment_form)

      # Mock analytics tracking
      page.execute_script(<<~JS)
        window.trackedEvents = [];
        window.analytics = {
          track: function(event, data) {
            window.trackedEvents.push({event: event, data: data});
          }
        };
      JS

      # Click Stripe setup action
      within('[data-payment-setup-target="requirementItem"][data-requirement="stripe_configuration"]') do
        click_button 'Configure'
      end

      # Verify event was tracked
      tracked_events = page.evaluate_script('window.trackedEvents')
      expect(tracked_events).to include(hash_including(
        'event' => 'payment_setup_interaction',
        'data' => hash_including('event_type' => 'setup_initiated', 'action' => 'stripe_configuration')
      ))
    end

    it 'tracks status update events' do
      visit edit_form_path(payment_form)

      # Mock analytics tracking
      page.execute_script(<<~JS)
        window.trackedEvents = [];
        window.analytics = {
          track: function(event, data) {
            window.trackedEvents.push({event: event, data: data});
          }
        };
      JS

      # Trigger status update
      page.execute_script(<<~JS)
        const controller = document.querySelector('[data-controller="payment-setup"]');
        const stimulusController = controller.stimulus;
        if (stimulusController) {
          stimulusController.updateSetupStatus();
        }
      JS

      # Verify status update event was tracked
      tracked_events = page.evaluate_script('window.trackedEvents')
      expect(tracked_events).to include(hash_including(
        'event' => 'payment_setup_interaction',
        'data' => hash_including('event_type' => 'status_updated')
      ))
    end
  end

  describe 'Error handling and edge cases' do
    it 'handles API errors gracefully during status polling' do
      # Mock failed API response
      Rails.application.routes.draw do
        namespace :api do
          namespace :v1 do
            get 'payment_setup/status', to: proc { |env|
              [500, {'Content-Type' => 'application/json'}, [
                { error: 'Internal server error' }.to_json
              ]]
            }
          end
        end
      end

      visit edit_form_path(payment_form)

      # Should handle error gracefully without breaking the UI
      expect(page).to have_text('Setup 0% complete')
      
      # Should not show error messages to user
      expect(page).not_to have_text('Internal server error')
    end

    it 'handles missing targets gracefully' do
      visit edit_form_path(payment_form)

      # Remove a target element and trigger update
      page.execute_script(<<~JS)
        const statusIndicator = document.querySelector('[data-payment-setup-target="statusIndicator"]');
        if (statusIndicator) statusIndicator.remove();
        
        const controller = document.querySelector('[data-controller="payment-setup"]');
        const stimulusController = controller.stimulus;
        if (stimulusController) {
          stimulusController.updateSetupStatus();
        }
      JS

      # Should not throw errors
      expect(page).not_to have_text('Error')
    end
  end

  describe 'Forms without payment questions' do
    let(:regular_form) { create(:form, user: user) }

    it 'hides setup requirements for forms without payment questions' do
      visit edit_form_path(regular_form)

      # Should not show setup checklist
      expect(page).not_to have_selector('[data-payment-setup-target="setupChecklist"]', visible: true)
    end
  end
end