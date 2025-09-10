require 'rails_helper'

RSpec.describe 'Premium Payment Questions', type: :feature do
  let(:freemium_user) { create(:user, subscription_tier: 'freemium') }
  let(:premium_user) { create(:user, subscription_tier: 'premium') }
  let(:form) { create(:form, user: freemium_user) }

  describe 'Freemium user restrictions' do
    before do
      sign_in freemium_user
    end

    it 'shows premium notice when selecting payment question type' do
      visit new_form_form_question_path(form)
      
      select 'Payment', from: 'Question type'
      
      expect(page).to have_content('Premium Feature')
      expect(page).to have_content('Payment questions are only available for Premium users')
    end

    it 'prevents creating payment questions' do
      visit new_form_form_question_path(form)
      
      fill_in 'Title', with: 'Payment Question'
      select 'Payment', from: 'Question type'
      click_button 'Create Question'
      
      expect(page).to have_content('Payment questions are only available for Premium users')
      expect(current_path).to eq(edit_form_path(form))
    end

    it 'prevents updating existing question to payment type' do
      question = create(:form_question, form: form, question_type: 'text_short')
      
      visit edit_form_form_question_path(form, question)
      
      select 'Payment', from: 'Question type'
      click_button 'Update Question'
      
      expect(page).to have_content('Payment questions are only available for Premium users')
      expect(current_path).to eq(edit_form_path(form))
    end

    it 'redirects from stripe settings page' do
      visit stripe_settings_path
      
      expect(page).to have_content('Payment processing requires a premium subscription')
      expect(current_path).to eq(root_path)
    end
  end

  describe 'Premium user access' do
    before do
      sign_in premium_user
    end

    it 'allows creating payment questions' do
      visit new_form_form_question_path(premium_user.forms.create!(name: 'Test Form'))
      
      fill_in 'Title', with: 'Payment Question'
      select 'Payment', from: 'Question type'
      click_button 'Create Question'
      
      expect(page).to have_content('Question was successfully created')
    end

    it 'allows access to stripe settings' do
      visit stripe_settings_path
      
      expect(page).to have_content('Payment Settings')
      expect(page).to have_content('Configure Stripe to accept payments')
    end
  end

  describe 'Form validation' do
    it 'prevents saving forms with payment questions for freemium users' do
      form = build(:form, user: freemium_user)
      form.form_questions.build(
        title: 'Payment Question',
        question_type: 'payment',
        position: 1
      )
      
      expect(form).not_to be_valid
      expect(form.errors[:base]).to include('Payment questions require a Premium subscription')
    end

    it 'allows saving forms with payment questions for premium users' do
      form = build(:form, user: premium_user)
      form.form_questions.build(
        title: 'Payment Question',
        question_type: 'payment',
        position: 1
      )
      
      expect(form).to be_valid
    end
  end

  describe 'Payment processing restrictions' do
    let(:form_with_payment) do
      form = create(:form, user: freemium_user)
      create(:form_question, form: form, question_type: 'payment')
      form
    end

    it 'shows unavailable message for freemium users in payment template' do
      visit public_form_path(form_with_payment.share_token)
      
      expect(page).to have_content('Payment Processing Unavailable')
      expect(page).to have_content('The form owner needs a Premium subscription')
    end
  end
end