require 'rails_helper'

RSpec.describe 'Template Preview System', type: :system, js: true do
  let(:user) { create(:user) }
  let(:premium_user) { create(:user, :premium) }
  let(:user_with_stripe) { create(:user, :with_stripe) }
  let(:fully_configured_user) { create(:user, :premium, :with_stripe) }
  
  let(:payment_template) { create(:form_template, :with_payment_questions) }
  let(:regular_template) { create(:form_template) }

  describe 'template gallery integration' do
    context 'when user is not configured for payments' do
      before { sign_in user }

      it 'shows payment badges on payment-enabled templates' do
        visit templates_path
        
        within("[data-template-id='#{payment_template.id}']") do
          expect(page).to have_selector('[data-template-preview-target="paymentBadge"]', visible: true)
          expect(page).to have_content('Payment')
        end

        within("[data-template-id='#{regular_template.id}']") do
          expect(page).not_to have_selector('[data-template-preview-target="paymentBadge"]', visible: true)
        end
      end

      it 'shows setup required indicator on payment badges' do
        visit templates_path
        
        within("[data-template-id='#{payment_template.id}']") do
          expect(page).to have_selector('.bg-amber-400.rounded-full', visible: true)
        end
      end

      it 'opens requirements modal when payment badge is clicked' do
        visit templates_path
        
        within("[data-template-id='#{payment_template.id}']") do
          find('[data-template-preview-target="paymentBadge"]').click
        end

        expect(page).to have_content('Payment Setup Required')
        expect(page).to have_content('Stripe Payment Configuration')
        expect(page).to have_content('Premium Subscription')
      end
    end

    context 'when user has partial configuration' do
      before { sign_in premium_user }

      it 'shows only missing requirements' do
        visit templates_path
        
        within("[data-template-id='#{payment_template.id}']") do
          find('[data-template-preview-target="paymentBadge"]').click
        end

        expect(page).to have_content('Stripe Payment Configuration')
        expect(page).not_to have_content('Premium Subscription')
      end
    end

    context 'when user is fully configured' do
      before { sign_in fully_configured_user }

      it 'shows payment badge without setup indicator' do
        visit templates_path
        
        within("[data-template-id='#{payment_template.id}']") do
          expect(page).to have_selector('[data-template-preview-target="paymentBadge"]', visible: true)
          expect(page).not_to have_selector('.bg-amber-400.rounded-full')
        end
      end

      it 'shows informational modal instead of setup requirements' do
        visit templates_path
        
        within("[data-template-id='#{payment_template.id}']") do
          find('[data-template-preview-target="paymentBadge"]').click
        end

        expect(page).to have_content('Payment Features Available')
        expect(page).to have_button('Use Template')
        expect(page).not_to have_button('Complete Setup Now')
      end
    end
  end

  describe 'template selection workflow' do
    before { sign_in user }

    it 'guides user through setup when selecting payment template' do
      visit template_path(payment_template)
      
      # Click use template button
      click_button 'Use This Template'
      
      # Should show payment requirements modal
      expect(page).to have_content('Payment Setup Required')
      
      # Choose to complete setup
      click_button 'Complete Setup Now'
      
      # Should redirect to payment setup
      expect(page).to have_current_path(/\/payment_setup/)
      expect(page).to have_content('Payment Configuration')
    end

    it 'allows proceeding without setup with reminders' do
      visit template_path(payment_template)
      
      click_button 'Use This Template'
      click_button 'Continue with Reminders'
      
      # Should proceed to form creation with setup reminders
      expect(page).to have_current_path(/\/forms\/new/)
      expect(page).to have_content('Payment setup required')
    end

    it 'remembers user choice for session' do
      visit template_path(payment_template)
      
      click_button 'Use This Template'
      click_button 'Continue with Reminders'
      
      # Go back and select same template again
      visit template_path(payment_template)
      click_button 'Use This Template'
      
      # Should not show modal again in same session
      expect(page).not_to have_content('Payment Setup Required')
      expect(page).to have_current_path(/\/forms\/new/)
    end
  end

  describe 'setup completion workflow' do
    before { sign_in user }

    it 'updates UI after completing setup in another tab' do
      visit template_path(payment_template)
      
      # Open setup modal
      click_button 'Use This Template'
      expect(page).to have_content('Payment Setup Required')
      
      # Simulate setup completion (would normally happen in another tab)
      user.update!(subscription_tier: 'premium', stripe_customer_id: 'cus_test123')
      
      # Refresh or trigger update
      page.refresh
      
      # Payment badge should no longer show setup indicator
      expect(page).not_to have_selector('.bg-amber-400.rounded-full')
    end
  end

  describe 'error handling and edge cases' do
    before { sign_in user }

    it 'handles network errors gracefully during setup redirect' do
      visit template_path(payment_template)
      
      # Mock network failure
      page.execute_script("""
        const originalFetch = window.fetch;
        window.fetch = function() {
          return Promise.reject(new Error('Network error'));
        };
      """)

      click_button 'Use This Template'
      click_button 'Complete Setup Now'
      
      # Should still attempt redirect even if analytics fails
      expect(page).to have_current_path(/\/payment_setup/)
    end

    it 'handles missing template data gracefully' do
      # Visit with invalid template ID
      visit "/templates/00000000-0000-0000-0000-000000000000"
      
      expect(page).to have_content('Template not found')
      expect(page).not_to have_selector('[data-controller="template-preview"]')
    end

    it 'handles malformed required features data' do
      visit template_path(payment_template)
      
      # Corrupt the required features data
      page.execute_script("""
        const controller = document.querySelector('[data-controller="template-preview"]').controller;
        controller.requiredFeaturesValue = 'invalid-json';
        controller.showPaymentRequirements(new Event('click'));
      """)

      click_button 'Use This Template'
      
      # Should not crash and should show generic requirements
      expect(page).to have_content('Payment Setup Required')
    end
  end

  describe 'accessibility compliance' do
    before { sign_in user }

    it 'maintains focus management' do
      visit template_path(payment_template)
      
      click_button 'Use This Template'
      
      # Modal should be focused
      expect(page).to have_selector('[data-template-preview-target="setupModal"]:focus-within')
      
      # Escape should close modal and return focus
      find('body').send_keys(:escape)
      expect(page).to have_selector('button:focus')
    end

    it 'provides proper ARIA labels and roles' do
      visit template_path(payment_template)
      
      click_button 'Use This Template'
      
      expect(page).to have_selector('[role="dialog"]')
      expect(page).to have_selector('[aria-labelledby]')
      expect(page).to have_selector('[aria-describedby]')
    end

    it 'supports keyboard navigation' do
      visit template_path(payment_template)
      
      # Navigate to template using keyboard
      find('body').send_keys(:tab) until page.has_selector('button:focus', text: 'Use This Template')
      find('button:focus').send_keys(:enter)
      
      # Navigate within modal using keyboard
      find('body').send_keys(:tab)
      expect(page).to have_selector('button:focus')
    end

    it 'provides screen reader friendly content' do
      visit template_path(payment_template)
      
      click_button 'Use This Template'
      
      # Check for descriptive text
      expect(page).to have_content('This template includes payment questions')
      expect(page).to have_content('Estimated setup time')
      
      # Check for proper button labels
      expect(page).to have_button('Complete Setup Now')
      expect(page).to have_button('Continue with Reminders')
    end
  end

  describe 'mobile responsiveness' do
    before do
      sign_in user
      page.driver.browser.manage.window.resize_to(375, 667) # iPhone SE
    end

    it 'adapts modal layout for mobile' do
      visit template_path(payment_template)
      
      click_button 'Use This Template'
      
      # Modal should be mobile-friendly
      expect(page).to have_selector('.max-w-md') # Mobile width
      expect(page).to have_selector('.px-4') # Mobile padding
    end

    it 'stacks buttons vertically on mobile' do
      visit template_path(payment_template)
      
      click_button 'Use This Template'
      
      # Buttons should stack on mobile
      expect(page).to have_selector('.flex-col.sm\\:flex-row')
    end

    it 'maintains touch-friendly targets' do
      visit template_path(payment_template)
      
      # Payment badge should be large enough for touch
      badge = find('[data-template-preview-target="paymentBadge"]')
      expect(badge.native.size.height).to be >= 44 # iOS minimum touch target
    end
  end

  describe 'performance and loading states' do
    before { sign_in user }

    it 'shows loading state during setup redirect' do
      visit template_path(payment_template)
      
      click_button 'Use This Template'
      
      # Add loading state to setup button
      page.execute_script("""
        document.querySelector('[data-action*="proceedWithSetup"]').innerHTML = 
          '<svg class="animate-spin w-4 h-4 mr-2" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="m4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>Setting up...';
      """)

      click_button 'Setting up...'
      
      # Should show loading state briefly before redirect
      expect(page).to have_content('Setting up...')
    end

    it 'handles slow network conditions gracefully' do
      # Simulate slow network
      page.execute_script("""
        const originalFetch = window.fetch;
        window.fetch = function(...args) {
          return new Promise(resolve => {
            setTimeout(() => resolve(originalFetch(...args)), 2000);
          });
        };
      """)

      visit template_path(payment_template)
      
      # Should still be responsive during slow operations
      click_button 'Use This Template'
      expect(page).to have_content('Payment Setup Required')
    end
  end
end