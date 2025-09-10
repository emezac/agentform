# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ResponsesController, type: :controller do
  let(:user) { create(:user) }
  let(:form) { create(:form, user: user, status: :published) }
  let!(:question) { create(:form_question, form: form, question_type: 'text_short', required: true) }
  
  describe 'GET #show' do
    context 'with valid form token' do
      it 'displays the form' do
        get :show, params: { share_token: form.share_token }
        
        expect(response).to have_http_status(:success)
        expect(assigns(:form)).to eq(form)
        expect(assigns(:current_question)).to eq(question)
      end
      
      it 'creates a new form response' do
        expect {
          get :show, params: { share_token: form.share_token }
        }.to change(FormResponse, :count).by(1)
        
        form_response = assigns(:form_response)
        expect(form_response.form).to eq(form)
        expect(form_response.status).to eq('in_progress')
      end
    end
    
    context 'with invalid form token' do
      it 'returns not found' do
        get :show, params: { share_token: 'invalid-token' }
        
        expect(response).to have_http_status(:not_found)
      end
    end
    
    context 'with unpublished form' do
      let(:draft_form) { create(:form, user: user, status: :draft) }
      
      it 'returns not found' do
        get :show, params: { share_token: draft_form.share_token }
        
        expect(response).to have_http_status(:not_found)
      end
    end
  end
  
  describe 'POST #answer' do
    let(:form_response) { create(:form_response, form: form) }
    
    before do
      session[:form_session_id] = form_response.session_id
    end
    
    context 'with valid answer data' do
      let(:answer_params) do
        {
          share_token: form.share_token,
          question_id: question.id,
          answer: {
            value: 'Test answer',
            started_at: 1.minute.ago.iso8601
          }
        }
      end
      
      it 'creates a question response' do
        expect {
          post :answer, params: answer_params, format: :json
        }.to change(QuestionResponse, :count).by(1)
        
        question_response = QuestionResponse.last
        expect(question_response.form_question).to eq(question)
        expect(question_response.form_response).to eq(form_response)
        expect(question_response.answer_data['value']).to eq('Test answer')
      end
      
      it 'returns success response' do
        post :answer, params: answer_params, format: :json
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
      end
    end
    
    context 'with invalid answer data' do
      let(:invalid_answer_params) do
        {
          share_token: form.share_token,
          question_id: question.id,
          answer: {
            value: '', # Empty required field
            started_at: 1.minute.ago.iso8601
          }
        }
      end
      
      it 'returns validation errors' do
        post :answer, params: invalid_answer_params, format: :json
        
        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['errors']).to be_present
      end
    end
  end
  
  describe 'GET #thank_you' do
    let(:completed_response) { create(:form_response, form: form, status: :completed) }
    
    before do
      session[:completed_response_session_id] = completed_response.session_id
    end
    
    it 'displays thank you page' do
      get :thank_you, params: { share_token: form.share_token }
      
      expect(response).to have_http_status(:success)
      expect(assigns(:form)).to eq(form)
      expect(assigns(:form_response)).to eq(completed_response)
    end
  end
  
  describe 'GET #preview' do
    it 'displays form in preview mode' do
      get :preview, params: { share_token: form.share_token }
      
      expect(response).to have_http_status(:success)
      expect(assigns(:preview_mode)).to be true
      expect(assigns(:current_question)).to eq(question)
    end
  end
  
  describe 'POST #save_draft' do
    let(:form_response) { create(:form_response, form: form) }
    
    before do
      session[:form_session_id] = form_response.session_id
    end
    
    it 'saves draft data' do
      draft_data = { 'question_1' => 'Draft answer' }
      
      post :save_draft, params: { 
        share_token: form.share_token,
        draft_data: draft_data
      }, format: :json
      
      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
    end
  end
  
  describe 'POST #abandon' do
    let(:form_response) { create(:form_response, form: form) }
    
    before do
      session[:form_session_id] = form_response.session_id
    end
    
    it 'marks response as abandoned' do
      post :abandon, params: { 
        share_token: form.share_token,
        reason: 'user_abandoned'
      }
      
      expect(response).to have_http_status(:ok)
      expect(form_response.reload.status).to eq('abandoned')
    end
  end
  
  describe 'private methods' do
    let(:controller_instance) { described_class.new }
    
    before do
      controller_instance.instance_variable_set(:@form, form)
      allow(controller_instance).to receive(:request).and_return(double(
        remote_ip: '127.0.0.1',
        user_agent: 'Test Agent',
        referer: 'http://example.com'
      ))
    end
    
    describe '#extract_utm_parameters' do
      it 'extracts UTM parameters from params' do
        params_hash = ActionController::Parameters.new({
          utm_source: 'google',
          utm_medium: 'cpc',
          utm_campaign: 'test_campaign'
        })
        allow(controller_instance).to receive(:params).and_return(params_hash)
        
        utm_data = controller_instance.send(:extract_utm_parameters)
        
        expect(utm_data).to eq({
          'utm_source' => 'google',
          'utm_medium' => 'cpc',
          'utm_campaign' => 'test_campaign'
        })
      end
    end
    
    describe '#calculate_response_time' do
      it 'calculates response time correctly' do
        started_at = 5.seconds.ago.iso8601
        
        response_time = controller_instance.send(:calculate_response_time, started_at)
        
        expect(response_time).to be_within(1000).of(5000) # 5 seconds in milliseconds
      end
      
      it 'returns 0 for invalid timestamp' do
        response_time = controller_instance.send(:calculate_response_time, 'invalid')
        
        expect(response_time).to eq(0)
      end
    end
  end
end