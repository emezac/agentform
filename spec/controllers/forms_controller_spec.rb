# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormsController, type: :controller do
  let(:user) { create(:user) }
  let(:form) { create(:form, user: user) }

  before do
    # Skip authentication for testing
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe 'GET #index' do
    it 'returns a success response' do
      get :index
      expect(response).to be_successful
    end

    it 'assigns @forms' do
      form # Create the form
      get :index
      expect(assigns(:forms)).to include(form)
    end
  end

  describe 'GET #show' do
    it 'returns a success response' do
      get :show, params: { id: form.id }
      expect(response).to be_successful
    end

    it 'assigns the requested form' do
      get :show, params: { id: form.id }
      expect(assigns(:form)).to eq(form)
    end
  end

  describe 'GET #new' do
    it 'returns a success response' do
      get :new
      expect(response).to be_successful
    end

    it 'assigns a new form' do
      get :new
      expect(assigns(:form)).to be_a_new(Form)
    end
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      let(:valid_attributes) do
        {
          name: 'Test Form',
          description: 'A test form',
          category: 'general'
        }
      end

      it 'creates a new Form' do
        expect {
          post :create, params: { form: valid_attributes }
        }.to change(Form, :count).by(1)
      end

      it 'redirects to the edit form page' do
        post :create, params: { form: valid_attributes }
        expect(response).to redirect_to(edit_form_path(Form.last))
      end
    end

    context 'with invalid parameters' do
      let(:invalid_attributes) do
        {
          name: '',
          description: 'A test form'
        }
      end

      it 'does not create a new Form' do
        expect {
          post :create, params: { form: invalid_attributes }
        }.not_to change(Form, :count)
      end

      it 'renders the new template' do
        post :create, params: { form: invalid_attributes }
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'PATCH #update' do
    context 'with valid parameters' do
      let(:new_attributes) do
        {
          name: 'Updated Form Name',
          description: 'Updated description'
        }
      end

      it 'updates the requested form' do
        patch :update, params: { id: form.id, form: new_attributes }
        form.reload
        expect(form.name).to eq('Updated Form Name')
        expect(form.description).to eq('Updated description')
      end

      it 'redirects to the form' do
        patch :update, params: { id: form.id, form: new_attributes }
        expect(response).to redirect_to(form)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the requested form' do
      form # Create the form
      expect {
        delete :destroy, params: { id: form.id }
      }.to change(Form, :count).by(-1)
    end

    it 'redirects to the forms list' do
      delete :destroy, params: { id: form.id }
      expect(response).to redirect_to(forms_path)
    end
  end

  describe 'POST #publish' do
    let(:form_with_questions) { create(:form, :with_questions, user: user) }

    context 'when form has regular questions' do
      it 'publishes the form' do
        post :publish, params: { id: form_with_questions.id }
        form_with_questions.reload
        expect(form_with_questions.status).to eq('published')
      end

      it 'redirects to the form' do
        post :publish, params: { id: form_with_questions.id }
        expect(response).to redirect_to(form_with_questions)
      end

      it 'does not run payment validation for non-payment forms' do
        expect(FormPublishValidationService).not_to receive(:new)
        post :publish, params: { id: form_with_questions.id }
      end

      it 'returns success JSON for API requests' do
        post :publish, params: { id: form_with_questions.id }, format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('published')
      end

      it 'returns success Turbo Stream response' do
        post :publish, params: { id: form_with_questions.id }, format: :turbo_stream
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('flash-messages')
        expect(response.body).to include('form-status-indicator')
      end
    end

    context 'when form has no questions' do
      it 'does not publish the form' do
        post :publish, params: { id: form.id }
        form.reload
        expect(form.status).not_to eq('published')
      end

      it 'redirects to edit with alert' do
        post :publish, params: { id: form.id }
        expect(response).to redirect_to(edit_form_path(form))
      end

      it 'returns appropriate JSON error for API requests' do
        post :publish, params: { id: form.id }, format: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['error']).to include('Cannot publish form without questions')
      end
    end

    context 'when form has payment questions' do
      let(:payment_form) { create(:form, :with_payment_questions, user: user) }

      context 'and user has complete payment setup' do
        before do
          # Stub the user methods directly on the form's user instance
          user_instance = payment_form.user
          allow(user_instance).to receive(:stripe_configured?).and_return(true)
          allow(user_instance).to receive(:premium?).and_return(true)
          allow(user_instance).to receive(:can_accept_payments?).and_return(true)
          # Ensure the form has payment questions
          payment_form.reload
        end

        it 'publishes the form successfully' do
          expect(payment_form.has_payment_questions?).to be_truthy
          post :publish, params: { id: payment_form.id }
          payment_form.reload
          expect(payment_form.status).to eq('published')
        end

        it 'redirects to the form with success notice' do
          post :publish, params: { id: payment_form.id }
          expect(response).to redirect_to(payment_form)
          expect(flash[:notice]).to eq('Form has been published successfully.')
        end

        it 'returns success JSON for API requests' do
          post :publish, params: { id: payment_form.id }, format: :json
          expect(response).to have_http_status(:ok)
          json_response = JSON.parse(response.body)
          expect(json_response['status']).to eq('published')
          expect(json_response['public_url']).to be_present
        end
      end

      context 'and user lacks Stripe configuration' do
        before do
          allow(payment_form.user).to receive(:stripe_configured?).and_return(false)
          allow(payment_form.user).to receive(:premium?).and_return(true)
          allow(payment_form.user).to receive(:can_accept_payments?).and_return(false)
          # Ensure the form has payment questions
          payment_form.reload
        end

        it 'does not publish the form' do
          expect(payment_form.has_payment_questions?).to be_truthy
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError)
          
          payment_form.reload
          expect(payment_form.status).not_to eq('published')
        end

        it 'raises PaymentValidationError with stripe_not_configured type' do
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('stripe_not_configured')
            expect(error.user_guidance[:action_url]).to eq('/stripe_settings')
          end
        end
      end

      context 'and user lacks Premium subscription' do
        before do
          allow(user).to receive(:stripe_configured?).and_return(true)
          allow(user).to receive(:premium?).and_return(false)
          allow(user).to receive(:can_accept_payments?).and_return(false)
        end

        it 'raises PaymentValidationError with premium_required type' do
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('premium_subscription_required')
            expect(error.user_guidance[:action_url]).to eq('/subscription_management')
          end
        end
      end

      context 'and user lacks both Stripe and Premium' do
        before do
          allow(user).to receive(:stripe_configured?).and_return(false)
          allow(user).to receive(:premium?).and_return(false)
          allow(user).to receive(:can_accept_payments?).and_return(false)
        end

        it 'raises PaymentValidationError with multiple_requirements type' do
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('multiple_requirements_missing')
            expect(error.user_guidance[:action_url]).to eq('/payment_setup_guide')
          end
        end
      end

      context 'with Turbo Stream requests' do
        before do
          allow(user).to receive(:stripe_configured?).and_return(false)
          allow(user).to receive(:premium?).and_return(true)
          allow(user).to receive(:can_accept_payments?).and_return(false)
        end

        it 'handles PaymentValidationError with Turbo Stream response' do
          # Mock the PaymentErrorHandling concern behavior
          allow(controller).to receive(:handle_payment_error_turbo_stream).and_call_original
          
          expect {
            post :publish, params: { id: payment_form.id }, format: :turbo_stream
          }.to raise_error(PaymentValidationError)
        end
      end

      context 'with enhanced error handling' do
        let(:payment_form) { create(:form, :with_payment_questions, user: user) }

        before do
          allow(user).to receive(:stripe_configured?).and_return(false)
          allow(user).to receive(:premium?).and_return(false)
          allow(user).to receive(:can_accept_payments?).and_return(false)
        end

        it 'includes form context in HTML error handling' do
          expect(controller).to receive(:handle_payment_error_html) do |error|
            expect(error).to be_a(PaymentValidationError)
            expect(controller.instance_variable_get(:@form)).to eq(payment_form)
          end

          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError)
        end

        it 'includes form context in JSON error handling' do
          expect(controller).to receive(:handle_payment_error_json) do |error|
            expect(error).to be_a(PaymentValidationError)
            expect(controller.instance_variable_get(:@form)).to eq(payment_form)
          end

          expect {
            post :publish, params: { id: payment_form.id }, format: :json
          }.to raise_error(PaymentValidationError)
        end

        it 'includes form context in Turbo Stream error handling' do
          expect(controller).to receive(:handle_payment_error_turbo_stream) do |error|
            expect(error).to be_a(PaymentValidationError)
            expect(controller.instance_variable_get(:@form)).to eq(payment_form)
          end

          expect {
            post :publish, params: { id: payment_form.id }, format: :turbo_stream
          }.to raise_error(PaymentValidationError)
        end
      end

      context 'with logging and debugging' do
        let(:payment_form) { create(:form, :with_payment_questions, user: user) }

        before do
          allow(user).to receive(:stripe_configured?).and_return(false)
          allow(user).to receive(:premium?).and_return(true)
          allow(user).to receive(:can_accept_payments?).and_return(false)
        end

        it 'logs payment validation process' do
          expect(Rails.logger).to receive(:info).with("Running pre-publish payment validation for form #{payment_form.id}")
          expect(Rails.logger).to receive(:warn).with(/Payment validation failure/)
          expect(Rails.logger).to receive(:warn).with(/Primary error type:/)

          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError)
        end
      end
    end

    context 'with FormPublishValidationService integration' do
      let(:payment_form) { create(:form, :with_payment_questions, user: user) }
      let(:validation_service) { instance_double(FormPublishValidationService) }
      let(:validation_result) { double('ServiceResult') }

      before do
        allow(FormPublishValidationService).to receive(:new).and_return(validation_service)
        allow(validation_service).to receive(:call).and_return(validation_result)
      end

      context 'when validation service succeeds' do
        before do
          allow(validation_service).to receive(:failure?).and_return(false)
          allow(validation_result).to receive(:result).and_return({
            can_publish: true,
            validation_errors: [],
            required_actions: []
          })
          allow(user).to receive(:stripe_configured?).and_return(true)
          allow(user).to receive(:premium?).and_return(true)
        end

        it 'calls the validation service' do
          post :publish, params: { id: payment_form.id }
          expect(FormPublishValidationService).to have_received(:new).with(form: payment_form)
          expect(validation_service).to have_received(:call)
        end

        it 'publishes the form when validation passes' do
          post :publish, params: { id: payment_form.id }
          payment_form.reload
          expect(payment_form.status).to eq('published')
        end
      end

      context 'when validation service fails' do
        before do
          allow(validation_service).to receive(:failure?).and_return(true)
          allow(validation_result).to receive(:result).and_return({
            can_publish: false,
            validation_errors: [{
              type: 'stripe_not_configured',
              title: 'Stripe Configuration Required',
              description: 'Configure Stripe to accept payments'
            }],
            required_actions: [{
              type: 'stripe_setup',
              action_url: '/stripe_settings',
              action_text: 'Configure Stripe'
            }]
          })
        end

        it 'raises appropriate PaymentValidationError' do
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('stripe_not_configured')
          end
        end
      end

      context 'when validation returns can_publish: false' do
        before do
          allow(validation_service).to receive(:failure?).and_return(false)
          allow(validation_result).to receive(:result).and_return({
            can_publish: false,
            validation_errors: [{
              type: 'premium_subscription_required',
              title: 'Premium Subscription Required',
              description: 'Upgrade to Premium to publish forms with payment questions'
            }],
            required_actions: [{
              type: 'subscription_upgrade',
              action_url: '/subscription_management',
              action_text: 'Upgrade Now'
            }]
          })
        end

        it 'raises appropriate PaymentValidationError' do
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('premium_subscription_required')
          end
        end
      end

      context 'when validation has multiple errors' do
        before do
          allow(validation_service).to receive(:failure?).and_return(false)
          allow(validation_result).to receive(:result).and_return({
            can_publish: false,
            validation_errors: [
              {
                type: 'payment_acceptance_disabled',
                title: 'Payment Acceptance Not Available',
                description: 'Complete payment setup to publish forms with payment questions'
              }
            ],
            required_actions: [
              {
                type: 'complete_payment_setup',
                action_url: '/payment_setup_guide',
                action_text: 'Complete Setup'
              }
            ]
          })
          allow(user).to receive(:stripe_configured?).and_return(false)
          allow(user).to receive(:premium?).and_return(false)
        end

        it 'raises PaymentValidationError with multiple requirements' do
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('multiple_requirements_missing')
            expect(error.required_actions).to include('complete_stripe_configuration')
            expect(error.required_actions).to include('complete_premium_subscription')
          end
        end
      end

      context 'when validation has payment question configuration errors' do
        before do
          allow(validation_service).to receive(:failure?).and_return(false)
          allow(validation_result).to receive(:result).and_return({
            can_publish: false,
            validation_errors: [{
              type: 'payment_question_configuration',
              title: 'Payment Question Configuration Missing',
              description: 'Payment questions are not properly configured'
            }],
            required_actions: [{
              type: 'configure_payment_question',
              action_url: "/forms/#{payment_form.id}/questions/1/edit",
              action_text: 'Configure Question'
            }]
          })
        end

        it 'raises PaymentValidationError for invalid configuration' do
          expect {
            post :publish, params: { id: payment_form.id }
          }.to raise_error(PaymentValidationError) do |error|
            expect(error.error_type).to eq('invalid_payment_configuration')
          end
        end
      end
    end
  end

  describe 'POST #unpublish' do
    let(:published_form) { create(:form, :published, user: user) }

    it 'unpublishes the form' do
      post :unpublish, params: { id: published_form.id }
      published_form.reload
      expect(published_form.status).to eq('draft')
    end
  end

  describe 'GET #analytics' do
    it 'returns a success response' do
      get :analytics, params: { id: form.id }
      expect(response).to be_successful
    end

    it 'assigns analytics data' do
      get :analytics, params: { id: form.id }
      expect(assigns(:analytics_data)).to be_present
    end
  end

  describe 'GET #preview' do
    it 'returns a success response' do
      get :preview, params: { id: form.id }
      expect(response).to be_successful
    end

    it 'sets preview mode' do
      get :preview, params: { id: form.id }
      expect(assigns(:preview_mode)).to be_truthy
    end
  end
end