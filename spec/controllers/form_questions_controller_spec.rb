# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormQuestionsController, type: :controller do
  let(:user) { create(:user) }
  let(:form) { create(:form, user: user) }
  let(:question) { create(:form_question, form: form) }

  before do
    # Skip authentication for testing controller logic
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:authorize).and_return(true)
    allow(controller).to receive(:policy_scope).and_return(FormQuestion.all)
    # Skip Pundit verification
    allow(controller).to receive(:verify_authorized).and_return(true)
    allow(controller).to receive(:verify_policy_scoped).and_return(true)
  end

  describe 'GET #index' do
    it 'returns a successful response' do
      get :index, params: { form_id: form.id }
      expect(response).to be_successful
    end

    it 'assigns @questions' do
      question # create the question
      get :index, params: { form_id: form.id }
      expect(assigns(:questions)).to include(question)
    end
  end

  describe 'GET #show' do
    it 'returns a successful response' do
      get :show, params: { form_id: form.id, id: question.id }
      expect(response).to be_successful
    end

    it 'assigns @question' do
      get :show, params: { form_id: form.id, id: question.id }
      expect(assigns(:question)).to eq(question)
    end
  end

  describe 'GET #new' do
    it 'returns a successful response' do
      get :new, params: { form_id: form.id }
      expect(response).to be_successful
    end

    it 'assigns a new question' do
      get :new, params: { form_id: form.id }
      expect(assigns(:question)).to be_a_new(FormQuestion)
    end
  end

  describe 'POST #create' do
    let(:valid_attributes) do
      {
        title: 'Test Question',
        question_type: 'text_short',
        required: true
      }
    end

    context 'with valid parameters' do
      it 'creates a new question' do
        expect {
          post :create, params: { form_id: form.id, form_question: valid_attributes }
        }.to change(FormQuestion, :count).by(1)
      end

      it 'redirects to the form edit page' do
        post :create, params: { form_id: form.id, form_question: valid_attributes }
        expect(response).to redirect_to(edit_form_path(form))
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new question' do
        expect {
          post :create, params: { form_id: form.id, form_question: { title: '' } }
        }.not_to change(FormQuestion, :count)
      end

      it 'renders the new template' do
        post :create, params: { form_id: form.id, form_question: { title: '' } }
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'PATCH #update' do
    let(:new_attributes) do
      {
        title: 'Updated Question Title',
        description: 'Updated description'
      }
    end

    it 'updates the question' do
      patch :update, params: { form_id: form.id, id: question.id, form_question: new_attributes }
      question.reload
      expect(question.title).to eq('Updated Question Title')
      expect(question.description).to eq('Updated description')
    end

    it 'redirects to the form edit page' do
      patch :update, params: { form_id: form.id, id: question.id, form_question: new_attributes }
      expect(response).to redirect_to(edit_form_path(form))
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the question' do
      question # create the question
      expect {
        delete :destroy, params: { form_id: form.id, id: question.id }
      }.to change(FormQuestion, :count).by(-1)
    end

    it 'redirects to the form edit page' do
      delete :destroy, params: { form_id: form.id, id: question.id }
      expect(response).to redirect_to(edit_form_path(form))
    end
  end

  describe 'POST #move_up' do
    let!(:question1) { create(:form_question, form: form, position: 1) }
    let!(:question2) { create(:form_question, form: form, position: 2) }

    it 'moves the question up' do
      post :move_up, params: { form_id: form.id, id: question2.id }
      question2.reload
      question1.reload
      expect(question2.position).to eq(1)
      expect(question1.position).to eq(2)
    end

    it 'does not move the first question up' do
      post :move_up, params: { form_id: form.id, id: question1.id }
      expect(response).to redirect_to(edit_form_path(form))
      expect(flash[:alert]).to include('already at the top')
    end
  end

  describe 'POST #move_down' do
    let!(:question1) { create(:form_question, form: form, position: 1) }
    let!(:question2) { create(:form_question, form: form, position: 2) }

    it 'moves the question down' do
      post :move_down, params: { form_id: form.id, id: question1.id }
      question1.reload
      question2.reload
      expect(question1.position).to eq(2)
      expect(question2.position).to eq(1)
    end

    it 'does not move the last question down' do
      post :move_down, params: { form_id: form.id, id: question2.id }
      expect(response).to redirect_to(edit_form_path(form))
      expect(flash[:alert]).to include('already at the bottom')
    end
  end

  describe 'POST #ai_enhance' do
    context 'when form has AI enabled' do
      before do
        allow_any_instance_of(Form).to receive(:ai_enhanced?).and_return(true)
      end

      it 'enhances the question with AI' do
        post :ai_enhance, params: { 
          form_id: form.id, 
          id: question.id, 
          enhancement_type: 'smart_validation' 
        }
        expect(response).to redirect_to(edit_form_path(form))
        expect(flash[:notice]).to include('enhanced with AI')
      end
    end

    context 'when form does not have AI enabled' do
      before do
        allow_any_instance_of(Form).to receive(:ai_enhanced?).and_return(false)
      end

      it 'returns an error' do
        post :ai_enhance, params: { 
          form_id: form.id, 
          id: question.id, 
          enhancement_type: 'smart_validation',
          format: :json
        }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['error']).to include('AI features not enabled')
      end
    end
  end

  describe 'GET #preview' do
    it 'returns a successful response' do
      get :preview, params: { form_id: form.id, id: question.id }
      expect(response).to be_successful
    end

    it 'sets preview mode' do
      get :preview, params: { form_id: form.id, id: question.id }
      expect(assigns(:preview_mode)).to be_truthy
    end
  end

  describe 'POST #reorder' do
    let!(:question1) { create(:form_question, form: form, position: 1) }
    let!(:question2) { create(:form_question, form: form, position: 2) }
    let!(:question3) { create(:form_question, form: form, position: 3) }

    it 'reorders questions successfully' do
      new_order = [question3.id, question1.id, question2.id]
      post :reorder, params: { form_id: form.id, question_ids: new_order }
      
      question1.reload
      question2.reload
      question3.reload
      
      expect(question3.position).to eq(1)
      expect(question1.position).to eq(2)
      expect(question2.position).to eq(3)
    end
  end

  describe 'GET #analytics' do
    it 'returns a successful response' do
      get :analytics, params: { form_id: form.id, id: question.id }
      expect(response).to be_successful
    end

    it 'assigns analytics data' do
      get :analytics, params: { form_id: form.id, id: question.id }
      expect(assigns(:question_analytics)).to be_present
      expect(assigns(:response_distribution)).to be_present
      expect(assigns(:performance_metrics)).to be_present
    end
  end

  context 'authorization' do
    let(:other_user) { create(:user) }
    let(:other_form) { create(:form, user: other_user) }

    it 'prevents access to other users forms' do
      get :index, params: { form_id: other_form.id }
      expect(response).to redirect_to(forms_path)
      expect(flash[:alert]).to include('Form not found')
    end
  end
end