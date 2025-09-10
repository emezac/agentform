require 'rails_helper'

RSpec.describe 'TemplatePreviewController Basic', type: :system, js: true do
  let(:user) { create(:user) }
  let(:template_with_payment) { create(:form_template, :with_payment_questions) }

  before do
    sign_in user
  end

  describe 'basic functionality' do
    it 'loads the template show page' do
      visit template_path(template_with_payment)
      
      expect(page).to have_content(template_with_payment.name)
      expect(page).to have_content(template_with_payment.description)
    end

    it 'shows payment badge for payment templates' do
      visit template_path(template_with_payment)
      
      expect(page).to have_selector('[data-template-preview-target="paymentBadge"]')
      expect(page).to have_content('Payment')
    end

    it 'has the template preview controller attached' do
      visit template_path(template_with_payment)
      
      expect(page).to have_selector('[data-controller="template-preview"]')
      expect(page).to have_selector('[data-template-preview-template-id-value]')
    end
  end
end