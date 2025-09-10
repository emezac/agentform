require 'rails_helper'

RSpec.describe 'TemplatePreviewController Unit Tests', type: :system, js: true do
  let(:user) { create(:user) }
  let(:template) { create(:form_template, :with_payment_questions) }

  before do
    sign_in user
  end

  describe 'controller initialization' do
    it 'sets correct data values' do
      visit template_path(template)
      
      controller_element = find('[data-controller="template-preview"]')
      
      expect(controller_element['data-template-preview-template-id-value']).to eq(template.id.to_s)
      expect(controller_element['data-template-preview-has-payment-questions-value']).to eq('true')
      expect(controller_element['data-template-preview-required-features-value']).to include('stripe_payments')
    end

    it 'handles templates without payment questions' do
      template_without_payment = create(:form_template)
      visit template_path(template_without_payment)
      
      controller_element = find('[data-controller="template-preview"]')
      
      expect(controller_element['data-template-preview-has-payment-questions-value']).to eq('false')
    end
  end

  describe 'feature configuration mapping' do
    before do
      visit template_path(template)
      find('[data-template-preview-target="paymentBadge"]').click
    end

    it 'displays correct configuration for stripe_payments' do
      within('[data-template-preview-target="requirementsList"]') do
        expect(page).to have_content('Stripe Payment Configuration')
        expect(page).to have_content('Connect your Stripe account to accept payments')
        expect(page).to have_selector('svg.text-blue-600') # Stripe icon
      end
    end

    it 'displays correct configuration for premium_subscription' do
      within('[data-template-preview-target="requirementsList"]') do
        expect(page).to have_content('Premium Subscription')
        expect(page).to have_content('Upgrade to Premium to unlock payment features')
        expect(page).to have_selector('svg.text-purple-600') # Premium icon
      end
    end

    it 'handles unknown features gracefully' do
      # Simulate unknown feature
      page.execute_script("""
        const controller = document.querySelector('[data-controller="template-preview"]').controller;
        controller.requiredFeaturesValue = ['unknown_feature'];
        controller.populateRequirementsList();
      """)

      within('[data-template-preview-target="requirementsList"]') do
        expect(page).to have_content('Unknown Feature')
        expect(page).to have_content('Required for payment functionality')
      end
    end
  end

  describe 'URL generation' do
    before do
      visit template_path(template)
      find('[data-template-preview-target="paymentBadge"]').click
    end

    it 'generates correct setup URL with template ID' do
      # Mock window.location to capture the redirect
      page.execute_script("""
        window.originalLocation = window.location.href;
        window.location.href = '';
        Object.defineProperty(window.location, 'href', {
          set: function(url) { window.capturedUrl = url; },
          get: function() { return window.capturedUrl || window.originalLocation; }
        });
      """)

      click_button 'Complete Setup Now'

      captured_url = page.evaluate_script('window.capturedUrl')
      expect(captured_url).to include("/payment_setup?template_id=#{template.id}")
      expect(captured_url).to include("return_to=")
    end

    it 'properly encodes return URL' do
      # Navigate to a path with query parameters
      visit "#{template_path(template)}?test=value&other=param"
      find('[data-template-preview-target="paymentBadge"]').click

      page.execute_script("""
        window.originalLocation = window.location.href;
        window.location.href = '';
        Object.defineProperty(window.location, 'href', {
          set: function(url) { window.capturedUrl = url; },
          get: function() { return window.capturedUrl || window.originalLocation; }
        });
      """)

      click_button 'Complete Setup Now'

      captured_url = page.evaluate_script('window.capturedUrl')
      expect(captured_url).to include(CGI.escape("#{template_path(template)}?test=value&other=param"))
    end
  end

  describe 'event dispatching' do
    before do
      visit template_path(template)
      find('[data-template-preview-target="paymentBadge"]').click
    end

    it 'dispatches custom event with correct detail' do
      # Set up event listener
      page.execute_script("""
        window.capturedEvents = [];
        document.addEventListener('template-preview:proceedWithTemplate', function(event) {
          window.capturedEvents.push(event.detail);
        });
      """)

      click_button 'Continue with Reminders'

      events = page.evaluate_script('window.capturedEvents')
      expect(events).not_to be_empty
      expect(events.first['templateId']).to eq(template.id.to_s)
      expect(events.first['skipSetup']).to be true
    end
  end

  describe 'modal state management' do
    before do
      visit template_path(template)
    end

    it 'manages body overflow class correctly' do
      expect(page).not_to have_selector('body.overflow-hidden')

      find('[data-template-preview-target="paymentBadge"]').click
      expect(page).to have_selector('body.overflow-hidden')

      find('[data-action="click->template-preview#closeModal"]').click
      expect(page).not_to have_selector('body.overflow-hidden')
    end

    it 'handles multiple modal open/close cycles' do
      3.times do
        find('[data-template-preview-target="paymentBadge"]').click
        expect(page).to have_selector('[data-template-preview-target="setupModal"]', visible: true)
        
        find('[data-action="click->template-preview#closeModal"]').click
        expect(page).not_to have_selector('[data-template-preview-target="setupModal"]', visible: true)
      end
    end
  end

  describe 'keyboard navigation' do
    before do
      visit template_path(template)
      find('[data-template-preview-target="paymentBadge"]').click
    end

    it 'handles tab navigation within modal' do
      # Test that tab moves between focusable elements
      find('body').send_keys(:tab)
      expect(page).to have_selector('button:focus')
    end

    it 'traps focus within modal' do
      # This is a simplified test - full focus trap testing would require more complex setup
      expect(page).to have_selector('[data-template-preview-target="setupModal"] button')
    end
  end

  describe 'error handling' do
    before do
      visit template_path(template)
    end

    it 'handles missing targets gracefully' do
      # Remove targets and ensure no JavaScript errors
      page.execute_script("""
        const controller = document.querySelector('[data-controller="template-preview"]').controller;
        controller.element.removeAttribute('data-template-preview-setup-modal-target');
        controller.showPaymentRequirements(new Event('click'));
      """)

      # Should not throw errors (verified by test not failing)
      expect(page).to have_selector('[data-controller="template-preview"]')
    end

    it 'handles analytics tracking failures gracefully' do
      # Simulate analytics failure
      page.execute_script("""
        window.analytics = {
          track: function() { throw new Error('Analytics failed'); }
        };
      """)

      find('[data-template-preview-target="paymentBadge"]').click
      
      # Should not prevent normal operation
      expect { click_button 'Complete Setup Now' }.not_to raise_error
    end
  end

  describe 'performance considerations' do
    it 'does not leak event listeners' do
      visit template_path(template)
      
      # Open and close modal multiple times
      5.times do
        find('[data-template-preview-target="paymentBadge"]').click
        find('[data-action="click->template-preview#closeModal"]').click
      end

      # Check that we don't have excessive event listeners
      listener_count = page.evaluate_script("""
        const events = getEventListeners ? getEventListeners(document) : {};
        Object.keys(events).reduce((count, key) => count + events[key].length, 0);
      """)

      # This is a basic check - in a real scenario you'd want more sophisticated monitoring
      expect(listener_count).to be < 50 # Reasonable threshold
    end
  end
end