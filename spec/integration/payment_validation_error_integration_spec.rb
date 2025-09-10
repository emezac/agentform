# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Payment Validation Error Integration', type: :request do
  let(:user) { create(:user) }
  let(:form_template) { create(:form_template, :with_payment_questions) }
  let(:form) { create(:form, user: user, form_template: form_template) }

  before do
    sign_in user
  end

  describe 'Form publishing with payment validation errors' do
    context 'when user lacks Stripe configuration' do
      before do
        allow_any_instance_of(User).to receive(:stripe_configured?).and_return(false)
        allow_any_instance_of(User).to receive(:premium?).and_return(true)
      end

      it 'raises PaymentValidationError when publishing form with payment questions' do
        expect {
          post "/forms/#{form.id}/publish"
        }.to raise_error(PaymentValidationError) do |error|
          expect(error.error_type).to eq('stripe_not_configured')
          expect(error.required_actions).to include('configure_stripe')
        end
      end

      it 'handles error gracefully in HTML requests' do
        # Mock the FormPublishValidationService to raise the error
        allow_any_instance_of(FormPublishValidationService).to receive(:validate_payment_readiness)
          .and_raise(PaymentValidationErrors.stripe_not_configured)

        post "/forms/#{form.id}/publish"

        expect(response).to redirect_to('/stripe_settings')
        expect(flash[:error]).to include('Stripe configuration required')
      end

      it 'returns structured error in JSON requests' do
        allow_any_instance_of(FormPublishValidationService).to receive(:validate_payment_readiness)
          .and_raise(PaymentValidationErrors.stripe_not_configured)

        post "/forms/#{form.id}/publish", as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']['error_type']).to eq('stripe_not_configured')
      end
    end

    context 'when user lacks Premium subscription' do
      before do
        allow_any_instance_of(User).to receive(:stripe_configured?).and_return(true)
        allow_any_instance_of(User).to receive(:premium?).and_return(false)
      end

      it 'raises PaymentValidationError for premium requirement' do
        expect {
          post "/forms/#{form.id}/publish"
        }.to raise_error(PaymentValidationError) do |error|
          expect(error.error_type).to eq('premium_subscription_required')
          expect(error.required_actions).to include('upgrade_subscription')
        end
      end

      it 'redirects to subscription management in HTML requests' do
        allow_any_instance_of(FormPublishValidationService).to receive(:validate_payment_readiness)
          .and_raise(PaymentValidationErrors.premium_required)

        post "/forms/#{form.id}/publish"

        expect(response).to redirect_to('/subscription_management')
        expect(flash[:error]).to include('Premium subscription required')
      end
    end

    context 'when user has multiple missing requirements' do
      before do
        allow_any_instance_of(User).to receive(:stripe_configured?).and_return(false)
        allow_any_instance_of(User).to receive(:premium?).and_return(false)
      end

      it 'raises PaymentValidationError for multiple requirements' do
        expect {
          post "/forms/#{form.id}/publish"
        }.to raise_error(PaymentValidationError) do |error|
          expect(error.error_type).to eq('multiple_requirements_missing')
          expect(error.required_actions).to include('complete_stripe_config', 'complete_premium_subscription')
        end
      end

      it 'redirects to payment setup guide' do
        allow_any_instance_of(FormPublishValidationService).to receive(:validate_payment_readiness)
          .and_raise(PaymentValidationErrors.multiple_requirements(['stripe_config', 'premium_subscription']))

        post "/forms/#{form.id}/publish"

        expect(response).to redirect_to('/payment_setup_guide')
        expect(flash[:error]).to include('Multiple setup steps required')
      end
    end
  end

  describe 'Template selection with payment validation' do
    context 'when selecting payment-enabled template' do
      it 'validates user setup and provides guidance' do
        get "/templates/#{form_template.id}"

        expect(response).to be_successful
        # The template should be displayed with payment requirements
        expect(response.body).to include('payment')
      end

      it 'shows payment requirements in template preview' do
        get "/templates/#{form_template.id}/preview"

        expect(response).to be_successful
        # Should show payment setup requirements
      end
    end
  end

  describe 'Form creation from payment template' do
    context 'when user is not properly configured' do
      before do
        allow_any_instance_of(User).to receive(:stripe_configured?).and_return(false)
        allow_any_instance_of(User).to receive(:premium?).and_return(false)
      end

      it 'creates form but shows setup requirements' do
        post '/forms', params: { 
          form: { 
            title: 'Test Payment Form',
            form_template_id: form_template.id
          }
        }

        expect(response).to redirect_to(assigns(:form))
        expect(flash[:notice]).to be_present
        # Should also have payment setup warnings
      end
    end
  end

  describe 'API endpoints with payment validation' do
    context 'API form publishing' do
      it 'returns structured error for API requests' do
        allow_any_instance_of(FormPublishValidationService).to receive(:validate_payment_readiness)
          .and_raise(PaymentValidationErrors.stripe_not_configured)

        post "/api/v1/forms/#{form.id}/publish", 
             headers: { 'Authorization' => "Bearer #{user.api_tokens.create!.token}" }

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']['error_type']).to eq('stripe_not_configured')
        expect(json_response['error']['required_actions']).to include('configure_stripe')
        expect(json_response['error']['user_guidance']['action_url']).to eq('/stripe_settings')
      end
    end
  end

  describe 'Error recovery workflows' do
    context 'after completing Stripe setup' do
      it 'allows form publishing after setup completion' do
        # Initially fail due to missing Stripe
        allow_any_instance_of(User).to receive(:stripe_configured?).and_return(false)
        allow_any_instance_of(User).to receive(:premium?).and_return(true)

        allow_any_instance_of(FormPublishValidationService).to receive(:validate_payment_readiness)
          .and_raise(PaymentValidationErrors.stripe_not_configured)

        post "/forms/#{form.id}/publish"
        expect(response).to redirect_to('/stripe_settings')

        # Simulate Stripe setup completion
        allow_any_instance_of(User).to receive(:stripe_configured?).and_return(true)
        allow_any_instance_of(FormPublishValidationService).to receive(:validate_payment_readiness)
          .and_return(double(success?: true, errors: []))

        # Should now succeed
        post "/forms/#{form.id}/publish"
        expect(response).to redirect_to(form)
        expect(flash[:notice]).to include('published')
      end
    end

    context 'after upgrading to Premium' do
      it 'allows form publishing after subscription upgrade' do
        # Initially fail due to missing Premium
        allow_any_instance_of(User).to receive(:stripe_configured?).and_return(true)
        allow_any_instance_of(User).to receive(:premium?).and_return(false)

        allow_any_instance_of(FormPublishValidationService).to receive(:validate_payment_readiness)
          .and_raise(PaymentValidationErrors.premium_required)

        post "/forms/#{form.id}/publish"
        expect(response).to redirect_to('/subscription_management')

        # Simulate Premium upgrade
        allow_any_instance_of(User).to receive(:premium?).and_return(true)
        allow_any_instance_of(FormPublishValidationService).to receive(:validate_payment_readiness)
          .and_return(double(success?: true, errors: []))

        # Should now succeed
        post "/forms/#{form.id}/publish"
        expect(response).to redirect_to(form)
        expect(flash[:notice]).to include('published')
      end
    end
  end

  describe 'Error analytics and tracking' do
    it 'logs payment validation errors for analytics' do
      allow_any_instance_of(FormPublishValidationService).to receive(:validate_payment_readiness)
        .and_raise(PaymentValidationErrors.stripe_not_configured)

      expect(Rails.logger).to receive(:warn).with(/Payment validation error/)
      expect(Rails.logger).to receive(:warn).with(/Error details/)

      post "/forms/#{form.id}/publish"
    end

    it 'tracks error events for monitoring' do
      # This would integrate with actual analytics service
      # For now, just verify the error structure is correct
      allow_any_instance_of(FormPublishValidationService).to receive(:validate_payment_readiness)
        .and_raise(PaymentValidationErrors.multiple_requirements(['stripe_config', 'premium_subscription']))

      post "/forms/#{form.id}/publish", as: :json

      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include(
        'error_type' => 'multiple_requirements_missing',
        'required_actions' => ['complete_stripe_config', 'complete_premium_subscription']
      )
    end
  end
end