# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormsController, type: :controller do
  let(:user) { create(:user, subscription_tier: 'freemium') }
  let(:premium_user) { create(:user, subscription_tier: 'premium', stripe_enabled: true, stripe_publishable_key: 'pk_test_123', stripe_secret_key: 'sk_test_123') }
  let(:form) { create(:form, user: user) }
  let(:form_with_payments) { create(:form, user: user) }
  let(:premium_form) { create(:form, user: premium_user) }

  before do
    sign_in user
    # Create payment questions for forms that need them
    create(:form_question, form: form_with_payments, question_type: 'payment', title: 'Payment Question')
    create(:form_question, form: premium_form, question_type: 'payment', title: 'Premium Payment Question')
  end

  describe 'GET #payment_setup_status' do
    context 'when user is authenticated' do
      it 'returns payment setup status for form without payment questions' do
        get :payment_setup_status, params: { id: form.id }, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response['has_payment_questions']).to be false
        expect(json_response['stripe_configured']).to be false
        expect(json_response['premium_subscription']).to be false
        expect(json_response['setup_complete']).to be true # No payment questions = setup complete
        expect(json_response['completion_percentage']).to eq(0)
        expect(json_response['missing_requirements']).to be_empty
      end

      it 'returns payment setup status for form with payment questions' do
        get :payment_setup_status, params: { id: form_with_payments.id }, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response['has_payment_questions']).to be true
        expect(json_response['stripe_configured']).to be false
        expect(json_response['premium_subscription']).to be false
        expect(json_response['setup_complete']).to be false
        expect(json_response['completion_percentage']).to eq(0)
        expect(json_response['missing_requirements']).to include('stripe_configuration', 'premium_subscription')
      end

      it 'returns complete setup status for premium user with Stripe' do
        sign_in premium_user
        get :payment_setup_status, params: { id: premium_form.id }, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response['has_payment_questions']).to be true
        expect(json_response['stripe_configured']).to be true
        expect(json_response['premium_subscription']).to be true
        expect(json_response['setup_complete']).to be true
        expect(json_response['completion_percentage']).to eq(100)
        expect(json_response['missing_requirements']).to be_empty
      end

      it 'returns partial setup status for premium user without Stripe' do
        premium_user_no_stripe = create(:user, subscription_tier: 'premium')
        form_premium_no_stripe = create(:form, user: premium_user_no_stripe)
        create(:form_question, form: form_premium_no_stripe, question_type: 'payment', title: 'Payment Question')
        
        sign_in premium_user_no_stripe
        get :payment_setup_status, params: { id: form_premium_no_stripe.id }, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response['stripe_configured']).to be false
        expect(json_response['premium_subscription']).to be true
        expect(json_response['setup_complete']).to be false
        expect(json_response['completion_percentage']).to eq(50)
        expect(json_response['missing_requirements']).to include('stripe_configuration')
        expect(json_response['missing_requirements']).not_to include('premium_subscription')
      end
    end

    context 'when user is not authenticated' do
      before { sign_out user }

      it 'redirects to sign in' do
        get :payment_setup_status, params: { id: form.id }, format: :json
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when user tries to access another user\'s form' do
      let(:other_user) { create(:user) }
      let(:other_form) { create(:form, user: other_user) }

      it 'returns not found' do
        expect {
          get :payment_setup_status, params: { id: other_form.id }, format: :json
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when superadmin accesses any form' do
      let(:superadmin) { create(:user, role: 'superadmin') }
      let(:any_user_form) { create(:form, user: create(:user)) }

      before { sign_in superadmin }

      it 'allows access to any form' do
        get :payment_setup_status, params: { id: any_user_form.id }, format: :json
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'GET #has_payment_questions' do
    context 'when user is authenticated' do
      it 'returns false for form without payment questions' do
        get :has_payment_questions, params: { id: form.id }, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response['has_payment_questions']).to be false
        expect(json_response['payment_questions_count']).to eq(0)
      end

      it 'returns true for form with payment questions' do
        get :has_payment_questions, params: { id: form_with_payments.id }, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response['has_payment_questions']).to be true
        expect(json_response['payment_questions_count']).to eq(1)
      end

      it 'returns correct count for form with multiple payment questions' do
        create(:form_question, form: form_with_payments, question_type: 'subscription', title: 'Subscription Question')
        create(:form_question, form: form_with_payments, question_type: 'donation', title: 'Donation Question')

        get :has_payment_questions, params: { id: form_with_payments.id }, format: :json

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response['has_payment_questions']).to be true
        expect(json_response['payment_questions_count']).to eq(3) # payment + subscription + donation
      end
    end

    context 'when user is not authenticated' do
      before { sign_out user }

      it 'redirects to sign in' do
        get :has_payment_questions, params: { id: form.id }, format: :json
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when user tries to access another user\'s form' do
      let(:other_user) { create(:user) }
      let(:other_form) { create(:form, user: other_user) }

      it 'returns not found' do
        expect {
          get :has_payment_questions, params: { id: other_form.id }, format: :json
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'Integration with existing form actions' do
    context 'when publishing form with payment questions' do
      it 'prevents publishing when setup is incomplete' do
        patch :publish, params: { id: form_with_payments.id }

        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to include('Payment configuration is required')
        expect(form_with_payments.reload.status).to eq('draft')
      end

      it 'allows publishing when setup is complete' do
        sign_in premium_user
        patch :publish, params: { id: premium_form.id }

        expect(response).to have_http_status(:redirect)
        expect(flash[:notice]).to include('Form has been published successfully')
        expect(premium_form.reload.status).to eq('published')
      end
    end

    context 'when editing form with payment questions' do
      it 'includes payment setup data in edit view' do
        get :edit, params: { id: form_with_payments.id }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('data-payment-setup-status-has-payment-questions-value="true"')
        expect(response.body).to include('data-payment-setup-status-stripe-configured-value="false"')
        expect(response.body).to include('data-payment-setup-status-is-premium-value="false"')
        expect(response.body).to include('data-payment-setup-status-setup-complete-value="false"')
      end

      it 'shows correct setup status for premium user' do
        sign_in premium_user
        get :edit, params: { id: premium_form.id }

        expect(response).to have_http_status(:success)
        expect(response.body).to include('data-payment-setup-status-stripe-configured-value="true"')
        expect(response.body).to include('data-payment-setup-status-is-premium-value="true"')
        expect(response.body).to include('data-payment-setup-status-setup-complete-value="true"')
        expect(response.body).to include('data-payment-setup-status-completion-percentage-value="100"')
      end
    end
  end

  describe 'Error handling' do
    context 'when form does not exist' do
      it 'returns not found for payment_setup_status' do
        expect {
          get :payment_setup_status, params: { id: 'nonexistent' }, format: :json
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'returns not found for has_payment_questions' do
        expect {
          get :has_payment_questions, params: { id: 'nonexistent' }, format: :json
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when requesting non-JSON format' do
      it 'handles HTML requests gracefully for payment_setup_status' do
        get :payment_setup_status, params: { id: form.id }
        expect(response).to have_http_status(:not_acceptable)
      end

      it 'handles HTML requests gracefully for has_payment_questions' do
        get :has_payment_questions, params: { id: form.id }
        expect(response).to have_http_status(:not_acceptable)
      end
    end
  end

  describe 'Performance considerations' do
    it 'does not trigger N+1 queries when checking payment setup status' do
      # Create multiple forms with payment questions
      forms_with_payments = create_list(:form, 3, user: user)
      forms_with_payments.each do |form|
        create(:form_question, form: form, question_type: 'payment', title: 'Payment Question')
      end

      expect {
        forms_with_payments.each do |form|
          get :payment_setup_status, params: { id: form.id }, format: :json
        end
      }.not_to exceed_query_limit(10) # Reasonable limit for these operations
    end
  end
end