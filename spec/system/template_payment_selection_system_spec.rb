# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Template Payment Selection System', type: :system do
  let(:user) { create(:user) }
  let(:premium_user) { create(:user, :premium) }
  let(:user_with_stripe) { create(:user, :with_stripe_configuration) }
  let(:premium_user_with_stripe) { create(:user, :premium, :with_stripe_configuration) }
  
  let(:regular_template) { create(:form_template, :public, name: 'Contact Form') }
  let(:payment_template) { create(:form_template, :public, :with_payment_questions, name: 'Event Registration') }

  before do
    # Stub the template analysis service to return payment requirements
    allow_any_instance_of(FormTemplate).to receive(:payment_requirements).and_return({
      has_payment_questions: payment_template == payment_template,
      required_features: payment_template == payment_template ? ['stripe_payments', 'premium_subscription'] : [],
      setup_complexity: payment_template == payment_template ? 'medium' : 'none'
    })
  end

  describe 'Template Gallery' do
    before { sign_in user }

    it 'displays all templates by default' do
      regular_template
      payment_template
      
      visit templates_path
      
      expect(page).to have_content('Contact Form')
      expect(page).to have_content('Event Registration')
      expect(page).to have_content('Showing 2 templates')
    end

    it 'filters templates by payment features' do
      regular_template
      payment_template
      
      visit templates_path
      
      # Filter to show only payment templates
      select 'With Payment Features', from: 'payment_features'
      
      expect(page).to have_content('Event Registration')
      expect(page).not_to have_content('Contact Form')
      expect(page).to have_content('Showing 1 template')
    end

    it 'filters templates without payment features' do
      regular_template
      payment_template
      
      visit templates_path
      
      # Filter to show only non-payment templates
      select 'Without Payment Features', from: 'payment_features'
      
      expect(page).to have_content('Contact Form')
      expect(page).not_to have_content('Event Registration')
      expect(page).to have_content('Showing 1 template')
    end

    it 'displays payment badges for payment-enabled templates' do
      payment_template
      
      visit templates_path
      
      within("[data-template-id='#{payment_template.id}']") do
        expect(page).to have_content('Payment')
        expect(page).to have_content('Payment Setup Required')
        expect(page).to have_content('Stripe payments')
        expect(page).to have_content('Premium subscription')
      end
    end

    it 'shows educational content when filtering payment templates' do
      payment_template
      
      visit templates_path
      select 'With Payment Features', from: 'payment_features'
      
      expect(page).to have_content('About Payment-Enabled Templates')
      expect(page).to have_content('Secure Stripe integration')
      expect(page).to have_content('Premium subscription required')
    end

    it 'allows searching templates' do
      regular_template
      payment_template
      
      visit templates_path
      
      fill_in 'search', with: 'Event'
      click_button 'Search'
      
      expect(page).to have_content('Event Registration')
      expect(page).not_to have_content('Contact Form')
    end

    it 'shows empty state when no templates match filters' do
      regular_template
      
      visit templates_path
      select 'With Payment Features', from: 'payment_features'
      
      expect(page).to have_content('No templates match your filters')
      expect(page).to have_content('Try adjusting your search criteria')
    end
  end

  describe 'Payment Requirements Modal' do
    before { sign_in user }

    it 'shows payment requirements modal when clicking payment template' do
      payment_template
      
      visit templates_path
      
      within("[data-template-id='#{payment_template.id}']") do
        click_button 'Use This Template'
      end
      
      expect(page).to have_content('Payment Setup Required')
      expect(page).to have_content('Stripe Payment Configuration')
      expect(page).to have_content('Premium Subscription')
      expect(page).to have_content('Estimated setup time: 5-10 minutes')
    end

    it 'allows proceeding with setup' do
      payment_template
      
      visit templates_path
      
      within("[data-template-id='#{payment_template.id}']") do
        click_button 'Use This Template'
      end
      
      click_button 'Complete Setup Now'
      
      expect(current_path).to include('/payment_setup')
      expect(page).to have_current_path(/template_id=#{payment_template.id}/)
    end

    it 'allows proceeding without setup' do
      payment_template
      
      visit templates_path
      
      within("[data-template-id='#{payment_template.id}']") do
        click_button 'Use This Template'
      end
      
      click_button 'Continue with Reminders'
      
      expect(page).to have_content('Form created from template')
      expect(page).to have_content('Remember to complete payment setup')
    end

    it 'can be closed with escape key', js: true do
      payment_template
      
      visit templates_path
      
      within("[data-template-id='#{payment_template.id}']") do
        click_button 'Use This Template'
      end
      
      expect(page).to have_content('Payment Setup Required')
      
      page.driver.browser.action.send_keys(:escape).perform
      
      expect(page).not_to have_content('Payment Setup Required')
    end
  end

  describe 'Template Instantiation Flow' do
    context 'with regular template' do
      before { sign_in user }

      it 'creates form directly without payment checks' do
        regular_template
        
        visit template_path(regular_template)
        click_button 'Use This Template'
        
        expect(page).to have_content('Form created from template')
        expect(current_path).to match(/\/forms\/\w+\/edit/)
      end
    end

    context 'with payment template and insufficient setup' do
      before { sign_in user }

      it 'redirects to payment setup when requirements not met' do
        payment_template
        
        visit template_path(payment_template)
        click_button 'Use This Template'
        
        expect(current_path).to include('/payment_setup')
        expect(page).to have_content('Payment setup required')
      end
    end

    context 'with payment template and complete setup' do
      before { sign_in premium_user_with_stripe }

      it 'creates form directly when all requirements are met' do
        payment_template
        
        visit template_path(payment_template)
        click_button 'Use This Template'
        
        expect(page).to have_content('Form created from template')
        expect(current_path).to match(/\/forms\/\w+\/edit/)
      end
    end
  end

  describe 'Template Preview Page' do
    before { sign_in user }

    it 'displays payment badge and requirements on template show page' do
      payment_template
      
      visit template_path(payment_template)
      
      expect(page).to have_content('Payment Features')
      expect(page).to have_content(payment_template.name)
      expect(page).to have_content(payment_template.description)
    end

    it 'shows sample questions with payment indicators' do
      payment_template
      
      visit template_path(payment_template)
      
      expect(page).to have_content('Template Preview')
      # Assuming the payment template has payment questions in its sample
      within('.space-y-4') do
        expect(page).to have_css('.bg-gray-50')
      end
    end
  end

  describe 'Analytics Tracking' do
    before { sign_in user }

    it 'tracks template gallery interactions', js: true do
      payment_template
      
      # Mock analytics
      page.execute_script("window.analytics = { track: function(event, props) { window.lastAnalyticsEvent = {event, props}; } }")
      
      visit templates_path
      
      # Check if page view was tracked
      analytics_event = page.evaluate_script('window.lastAnalyticsEvent')
      expect(analytics_event['event']).to eq('template_gallery_viewed')
    end

    it 'tracks filter changes', js: true do
      payment_template
      
      # Mock analytics
      page.execute_script("window.analytics = { track: function(event, props) { window.lastAnalyticsEvent = {event, props}; } }")
      
      visit templates_path
      select 'With Payment Features', from: 'payment_features'
      
      # Wait for analytics to be called
      sleep(0.1)
      
      analytics_event = page.evaluate_script('window.lastAnalyticsEvent')
      expect(analytics_event['event']).to eq('template_filter_applied')
      expect(analytics_event['props']['filter_name']).to eq('payment_features')
    end
  end

  describe 'Responsive Design' do
    before { sign_in user }

    it 'displays properly on mobile devices' do
      payment_template
      
      page.driver.browser.manage.window.resize_to(375, 667) # iPhone SE size
      
      visit templates_path
      
      expect(page).to have_content('Form Templates')
      expect(page).to have_content(payment_template.name)
      
      # Check that filters are still accessible
      expect(page).to have_select('payment_features')
    end
  end

  describe 'Error Handling' do
    before { sign_in user }

    it 'handles template instantiation errors gracefully' do
      payment_template
      
      # Mock an error in template instantiation
      allow_any_instance_of(FormTemplate).to receive(:instantiate_for_user).and_raise(StandardError, 'Test error')
      
      visit template_path(payment_template)
      
      within("[data-template-id='#{payment_template.id}']") do
        click_button 'Use This Template'
      end
      
      click_button 'Continue with Reminders'
      
      expect(page).to have_content('Error creating form')
      expect(current_path).to eq(templates_path)
    end
  end
end