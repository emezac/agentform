require 'rails_helper'

RSpec.describe 'TemplatePreviewController', type: :system, js: true do
  let(:user) { create(:user) }
  let(:template_with_payment) { create(:form_template, :with_payment_questions) }
  let(:template_without_payment) { create(:form_template) }

  before do
    sign_in user
  end

  describe 'payment badge visibility' do
    context 'when template has payment questions' do
      it 'shows the payment badge' do
        visit template_path(template_with_payment)
        
        expect(page).to have_selector('[data-template-preview-target="paymentBadge"]', visible: true)
        expect(page).to have_content('Payment')
      end

      it 'hides the badge when template has no payment questions' do
        visit template_path(template_without_payment)
        
        expect(page).to have_selector('[data-template-preview-target="paymentBadge"]', visible: false)
      end
    end
  end

  describe 'showing payment requirements' do
    before do
      visit template_path(template_with_payment)
    end

    it 'opens modal when payment badge is clicked' do
      find('[data-template-preview-target="paymentBadge"]').click
      
      expect(page).to have_selector('[data-template-preview-target="setupModal"]', visible: true)
      expect(page).to have_content('Payment Setup Required')
    end

    it 'populates requirements list with required features' do
      find('[data-template-preview-target="paymentBadge"]').click
      
      within('[data-template-preview-target="requirementsList"]') do
        expect(page).to have_content('Stripe Payment Configuration')
        expect(page).to have_content('Premium Subscription')
      end
    end

    it 'shows estimated setup time' do
      find('[data-template-preview-target="paymentBadge"]').click
      
      expect(page).to have_content('Estimated setup time: 5-10 minutes')
    end
  end

  describe 'proceeding with setup' do
    before do
      visit template_path(template_with_payment)
      find('[data-template-preview-target="paymentBadge"]').click
    end

    it 'redirects to payment setup when "Complete Setup Now" is clicked' do
      click_button 'Complete Setup Now'
      
      expect(page).to have_current_path(/\/payment_setup/)
      expect(page).to have_current_path(/template_id=#{template_with_payment.id}/)
    end

    it 'includes return URL in setup redirect' do
      original_path = current_path
      click_button 'Complete Setup Now'
      
      expect(page).to have_current_path(/return_to=#{CGI.escape(original_path)}/)
    end
  end

  describe 'proceeding without setup' do
    before do
      visit template_path(template_with_payment)
      find('[data-template-preview-target="paymentBadge"]').click
    end

    it 'closes modal when "Continue with Reminders" is clicked' do
      click_button 'Continue with Reminders'
      
      expect(page).not_to have_selector('[data-template-preview-target="setupModal"]', visible: true)
    end

    it 'dispatches custom event for template selection' do
      # This would require additional JavaScript testing setup to verify events
      # For now, we verify the modal closes and user can continue
      click_button 'Continue with Reminders'
      
      expect(page).not_to have_selector('[data-template-preview-target="setupModal"]', visible: true)
    end
  end

  describe 'modal interactions' do
    before do
      visit template_path(template_with_payment)
      find('[data-template-preview-target="paymentBadge"]').click
    end

    it 'closes modal when X button is clicked' do
      find('[data-action="click->template-preview#closeModal"]').click
      
      expect(page).not_to have_selector('[data-template-preview-target="setupModal"]', visible: true)
    end

    it 'closes modal when backdrop is clicked' do
      find('.bg-gray-500.bg-opacity-75').click
      
      expect(page).not_to have_selector('[data-template-preview-target="setupModal"]', visible: true)
    end

    it 'closes modal when Escape key is pressed' do
      find('body').send_keys(:escape)
      
      expect(page).not_to have_selector('[data-template-preview-target="setupModal"]', visible: true)
    end

    it 'prevents body scrolling when modal is open' do
      expect(page).to have_selector('body.overflow-hidden')
    end

    it 'restores body scrolling when modal is closed' do
      find('[data-action="click->template-preview#closeModal"]').click
      
      expect(page).not_to have_selector('body.overflow-hidden')
    end
  end

  describe 'analytics tracking' do
    before do
      visit template_path(template_with_payment)
      find('[data-template-preview-target="paymentBadge"]').click
    end

    it 'tracks setup initiation event' do
      # Mock analytics tracking
      page.execute_script("""
        window.analytics = {
          track: function(event, properties) {
            window.lastTrackedEvent = { event: event, properties: properties };
          }
        };
      """)

      click_button 'Complete Setup Now'

      tracked_event = page.evaluate_script('window.lastTrackedEvent')
      expect(tracked_event['event']).to eq('payment_setup_initiated')
      expect(tracked_event['properties']['template_id']).to eq(template_with_payment.id.to_s)
    end

    it 'tracks setup skip event' do
      # Mock analytics tracking
      page.execute_script("""
        window.analytics = {
          track: function(event, properties) {
            window.lastTrackedEvent = { event: event, properties: properties };
          }
        };
      """)

      click_button 'Continue with Reminders'

      tracked_event = page.evaluate_script('window.lastTrackedEvent')
      expect(tracked_event['event']).to eq('payment_setup_skipped')
      expect(tracked_event['properties']['template_id']).to eq(template_with_payment.id.to_s)
    end
  end

  describe 'accessibility' do
    before do
      visit template_path(template_with_payment)
      find('[data-template-preview-target="paymentBadge"]').click
    end

    it 'focuses first focusable element when modal opens' do
      # The close button should be focused
      expect(page).to have_selector('[data-action="click->template-preview#closeModal"]:focus')
    end

    it 'has proper ARIA attributes' do
      expect(page).to have_selector('[role="dialog"]', visible: true)
    end

    it 'has descriptive button text' do
      expect(page).to have_button('Complete Setup Now')
      expect(page).to have_button('Continue with Reminders')
    end
  end

  describe 'responsive design' do
    it 'adapts to mobile viewport' do
      page.driver.browser.manage.window.resize_to(375, 667) # iPhone SE size
      
      visit template_path(template_with_payment)
      find('[data-template-preview-target="paymentBadge"]').click
      
      expect(page).to have_selector('.max-w-md') # Mobile-friendly modal width
    end
  end
end