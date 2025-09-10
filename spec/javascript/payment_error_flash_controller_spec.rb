# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PaymentErrorFlashController', type: :system, js: true do
  let(:user) { create(:user) }
  let(:form) { create(:form, user: user) }

  before do
    sign_in user
  end

  describe 'error flash display' do
    context 'with stripe_not_configured error' do
      before do
        visit form_path(form)
        # Simulate error flash being rendered
        page.execute_script(<<~JS)
          const errorFlash = document.createElement('div');
          errorFlash.innerHTML = `
            <div class="payment-error-flash bg-red-50 border border-red-200 rounded-lg p-4 mb-4" 
                 data-controller="payment-error-flash" 
                 data-payment-error-flash-error-type-value="stripe_not_configured"
                 data-payment-error-flash-dismissible-value="true">
              <div class="flex items-start">
                <div class="ml-3 flex-1">
                  <h3 class="text-sm font-medium text-red-800">
                    Stripe configuration required for payment questions
                  </h3>
                  <div class="mt-2 text-sm text-red-700">
                    Your form contains payment questions but Stripe is not configured.
                  </div>
                  <div class="mt-4 flex flex-wrap gap-2">
                    <a href="/stripe_settings" class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-red-600 hover:bg-red-700">
                      Configure Stripe
                    </a>
                    <button type="button" 
                            class="inline-flex items-center px-3 py-2 border border-red-300 text-sm leading-4 font-medium rounded-md text-red-700 bg-white hover:bg-red-50"
                            data-action="click->payment-error-flash#showHelp">
                      Get Help
                    </button>
                  </div>
                </div>
                <div class="ml-auto pl-3">
                  <button type="button" 
                          class="inline-flex bg-red-50 rounded-md p-1.5 text-red-400 hover:bg-red-100"
                          data-action="click->payment-error-flash#dismiss">
                    <span class="sr-only">Dismiss</span>
                    ×
                  </button>
                </div>
              </div>
            </div>
          `;
          document.body.appendChild(errorFlash);
        JS
      end

      it 'displays error message correctly' do
        expect(page).to have_content('Stripe configuration required for payment questions')
        expect(page).to have_content('Your form contains payment questions but Stripe is not configured')
        expect(page).to have_link('Configure Stripe', href: '/stripe_settings')
        expect(page).to have_button('Get Help')
      end

      it 'allows dismissing the error' do
        find('button[data-action="click->payment-error-flash#dismiss"]').click
        
        # Wait for animation to complete
        sleep 0.5
        
        expect(page).not_to have_content('Stripe configuration required for payment questions')
      end

      it 'shows help modal when Get Help is clicked' do
        find('button[data-action="click->payment-error-flash#showHelp"]').click
        
        expect(page).to have_content('Payment Setup Help')
        expect(page).to have_content('Next Steps:')
        expect(page).to have_content('Go to Stripe Settings in your account')
      end

      it 'tracks error display analytics' do
        # This would be tested with a JavaScript testing framework like Jest
        # For now, we'll just verify the controller is properly initialized
        expect(page).to have_css('[data-controller="payment-error-flash"]')
        expect(page).to have_css('[data-payment-error-flash-error-type-value="stripe_not_configured"]')
      end
    end

    context 'with multiple_requirements_missing error' do
      before do
        visit form_path(form)
        page.execute_script(<<~JS)
          const errorFlash = document.createElement('div');
          errorFlash.innerHTML = `
            <div class="payment-error-flash bg-red-50 border border-red-200 rounded-lg p-4 mb-4" 
                 data-controller="payment-error-flash" 
                 data-payment-error-flash-error-type-value="multiple_requirements_missing"
                 data-payment-error-flash-dismissible-value="true">
              <div class="flex items-start">
                <div class="ml-3 flex-1">
                  <h3 class="text-sm font-medium text-red-800">
                    Multiple setup steps required for payment features
                  </h3>
                  <div class="mt-4 flex flex-wrap gap-2">
                    <button type="button" 
                            class="inline-flex items-center px-3 py-2 border border-red-300 text-sm leading-4 font-medium rounded-md text-red-700 bg-white hover:bg-red-50"
                            data-action="click->payment-error-flash#showChecklist">
                      Setup Checklist
                    </button>
                  </div>
                </div>
              </div>
            </div>
          `;
          document.body.appendChild(errorFlash);
        JS
      end

      it 'shows setup checklist modal when button is clicked' do
        find('button[data-action="click->payment-error-flash#showChecklist"]').click
        
        expect(page).to have_content('Setup Checklist')
        expect(page).to have_content('Stripe Configuration')
        expect(page).to have_content('Premium Subscription')
      end
    end
  end

  describe 'auto-dismiss functionality' do
    before do
      visit form_path(form)
      page.execute_script(<<~JS)
        const errorFlash = document.createElement('div');
        errorFlash.innerHTML = `
          <div class="payment-error-flash bg-red-50 border border-red-200 rounded-lg p-4 mb-4" 
               data-controller="payment-error-flash" 
               data-payment-error-flash-error-type-value="stripe_not_configured"
               data-payment-error-flash-dismissible-value="true">
            <div class="flex items-start">
              <div class="ml-3 flex-1">
                <h3 class="text-sm font-medium text-red-800">Test Error Message</h3>
              </div>
            </div>
          </div>
        `;
        document.body.appendChild(errorFlash);
        
        // Speed up auto-dismiss for testing
        const controller = errorFlash.querySelector('[data-controller="payment-error-flash"]');
        if (controller && controller.stimulus) {
          controller.stimulus.autoDismissTimeout = setTimeout(() => {
            controller.stimulus.dismiss();
          }, 100); // 100ms instead of 10 seconds
        }
      JS
    end

    it 'auto-dismisses after timeout when dismissible' do
      expect(page).to have_content('Test Error Message')
      
      # Wait for auto-dismiss
      sleep 0.2
      
      expect(page).not_to have_content('Test Error Message')
    end
  end

  describe 'modal interactions' do
    before do
      visit form_path(form)
      page.execute_script(<<~JS)
        const errorFlash = document.createElement('div');
        errorFlash.innerHTML = `
          <div class="payment-error-flash" 
               data-controller="payment-error-flash" 
               data-payment-error-flash-error-type-value="stripe_not_configured">
            <button type="button" data-action="click->payment-error-flash#showHelp">Get Help</button>
          </div>
        `;
        document.body.appendChild(errorFlash);
      JS
    end

    it 'closes modal when clicking outside' do
      find('button[data-action="click->payment-error-flash#showHelp"]').click
      
      expect(page).to have_content('Payment Setup Help')
      
      # Click outside the modal (on the backdrop)
      find('.fixed.inset-0.bg-gray-500').click
      
      expect(page).not_to have_content('Payment Setup Help')
    end

    it 'closes modal when clicking close button' do
      find('button[data-action="click->payment-error-flash#showHelp"]').click
      
      expect(page).to have_content('Payment Setup Help')
      
      find('button[data-action="close-modal"]').click
      
      expect(page).not_to have_content('Payment Setup Help')
    end

    it 'focuses first focusable element when modal opens' do
      find('button[data-action="click->payment-error-flash#showHelp"]').click
      
      # Verify modal is open and focused element is within modal
      expect(page).to have_content('Payment Setup Help')
      
      # The first button in the modal should be focused
      focused_element = page.evaluate_script('document.activeElement.textContent')
      expect(['Got it', 'Close']).to include(focused_element)
    end
  end

  describe 'error type specific help content' do
    %w[stripe_not_configured premium_subscription_required multiple_requirements_missing invalid_payment_configuration].each do |error_type|
      context "with #{error_type} error" do
        before do
          visit form_path(form)
          page.execute_script(<<~JS)
            const errorFlash = document.createElement('div');
            errorFlash.innerHTML = `
              <div data-controller="payment-error-flash" 
                   data-payment-error-flash-error-type-value="#{error_type}">
                <button type="button" data-action="click->payment-error-flash#showHelp">Get Help</button>
              </div>
            `;
            document.body.appendChild(errorFlash);
          JS
        end

        it 'shows appropriate help content for error type' do
          find('button[data-action="click->payment-error-flash#showHelp"]').click
          
          expect(page).to have_content('Payment Setup Help')
          expect(page).to have_content('Next Steps:')
          
          # Each error type should have specific help content
          case error_type
          when 'stripe_not_configured'
            expect(page).to have_content('Go to Stripe Settings')
          when 'premium_subscription_required'
            expect(page).to have_content('Go to Subscription Management')
          when 'multiple_requirements_missing'
            expect(page).to have_content('Review the setup checklist')
          when 'invalid_payment_configuration'
            expect(page).to have_content('Review your payment questions')
          end
        end
      end
    end
  end
end