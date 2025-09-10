# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TemplatesController, type: :controller do
  let(:user) { create(:user) }
  let(:regular_template) { create(:form_template, :public, name: 'Contact Form') }
  let(:payment_template) { create(:form_template, :public, :with_payment_questions, name: 'Event Registration') }

  before do
    sign_in user
    
    # Stub the template analysis service to return payment requirements
    allow_any_instance_of(FormTemplate).to receive(:payment_requirements).and_return({
      has_payment_questions: false,
      required_features: [],
      setup_complexity: 'none'
    })
    
    allow(payment_template).to receive(:payment_requirements).and_return({
      has_payment_questions: true,
      required_features: ['stripe_payments', 'premium_subscription'],
      setup_complexity: 'medium'
    })
  end

  describe 'GET #index' do
    it 'displays all templates by default' do
      regular_template
      payment_template
      
      get :index
      
      expect(response).to be_successful
      expect(assigns(:templates)).to include(regular_template, payment_template)
    end

    it 'filters templates by payment features' do
      regular_template
      payment_template
      
      get :index, params: { payment_features: 'with_payments' }
      
      expect(response).to be_successful
      expect(assigns(:templates)).to include(payment_template)
      expect(assigns(:templates)).not_to include(regular_template)
    end

    it 'filters templates without payment features' do
      regular_template
      payment_template
      
      get :index, params: { payment_features: 'without_payments' }
      
      expect(response).to be_successful
      expect(assigns(:templates)).to include(regular_template)
      expect(assigns(:templates)).not_to include(payment_template)
    end

    it 'filters by category' do
      regular_template
      payment_template
      
      get :index, params: { category: 'event_registration' }
      
      expect(response).to be_successful
      expect(assigns(:templates)).to include(payment_template)
      expect(assigns(:templates)).not_to include(regular_template)
    end

    it 'searches templates by name' do
      regular_template
      payment_template
      
      get :index, params: { search: 'Event' }
      
      expect(response).to be_successful
      expect(assigns(:templates)).to include(payment_template)
      expect(assigns(:templates)).not_to include(regular_template)
    end

    it 'sorts templates by popularity' do
      popular_template = create(:form_template, :public, usage_count: 100)
      regular_template
      
      get :index, params: { sort_by: 'popular' }
      
      expect(response).to be_successful
      templates = assigns(:templates)
      expect(templates.first).to eq(popular_template)
    end

    it 'sets filter state variables' do
      get :index, params: { 
        payment_features: 'with_payments', 
        category: 'event_registration',
        sort_by: 'popular'
      }
      
      expect(assigns(:has_payment_filter)).to be true
      expect(assigns(:category_filter)).to eq('event_registration')
      expect(assigns(:sort_by)).to eq('popular')
    end
  end

  describe 'POST #instantiate' do
    context 'with regular template' do
      it 'creates form directly without payment checks' do
        expect {
          post :instantiate, params: { id: regular_template.id }
        }.to change(Form, :count).by(1)
        
        expect(response).to redirect_to(edit_form_path(Form.last))
        expect(flash[:notice]).to include("Form created from template")
      end
    end

    context 'with payment template and insufficient setup' do
      before do
        # Mock the validation service to return failure
        allow(PaymentSetupValidationService).to receive(:call).and_return(
          double(success?: false, errors: ['Stripe not configured'])
        )
      end

      it 'redirects to payment setup when requirements not met' do
        post :instantiate, params: { id: payment_template.id }
        
        expect(response).to redirect_to(payment_setup_path(template_id: payment_template.id, return_to: templates_path))
        expect(flash[:alert]).to include("Payment setup required")
      end
    end

    context 'with payment template and skip setup' do
      it 'creates form with setup reminder when skipping setup' do
        expect {
          post :instantiate, params: { id: payment_template.id, skip_setup: 'true' }
        }.to change(Form, :count).by(1)
        
        expect(response).to redirect_to(edit_form_path(Form.last))
        expect(flash[:notice]).to include("Remember to complete payment setup")
      end
    end

    context 'with payment template and complete setup' do
      before do
        # Mock the validation service to return success
        allow(PaymentSetupValidationService).to receive(:call).and_return(
          double(success?: true)
        )
      end

      it 'creates form directly when all requirements are met' do
        expect {
          post :instantiate, params: { id: payment_template.id }
        }.to change(Form, :count).by(1)
        
        expect(response).to redirect_to(edit_form_path(Form.last))
        expect(flash[:notice]).to include("Form created from template")
        expect(flash[:notice]).not_to include("Remember to complete")
      end
    end
  end
end