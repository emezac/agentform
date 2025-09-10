# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ResponsesController, type: :controller do
  let(:user) { create(:user) }
  let(:api_token) { create(:api_token, user: user) }
  let(:form) { create(:form, user: user) }
  let(:question) { create(:form_question, form: form) }
  let(:form_response) { create(:form_response, form: form) }

  before do
    request.headers['Authorization'] = "Bearer #{api_token.token}"
  end

  describe 'GET #index' do
    let!(:responses) { create_list(:form_response, 3, form: form) }

    it 'returns all responses for the form' do
      get :index, params: { form_id: form.id }

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['data']['responses']).to be_an(Array)
      expect(json_response['data']['responses'].length).to eq(3)
    end

    it 'applies status filter' do
      completed_response = create(:form_response, form: form, status: :completed)
      
      get :index, params: { form_id: form.id, status: 'completed' }

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['data']['responses'].length).to eq(1)
      expect(json_response['data']['responses'][0]['id']).to eq(completed_response.id)
    end

    it 'applies date range filter' do
      old_response = create(:form_response, form: form, created_at: 1.week.ago)
      recent_response = create(:form_response, form: form, created_at: 1.day.ago)

      get :index, params: { 
        form_id: form.id, 
        start_date: 3.days.ago.to_date.to_s 
      }

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      response_ids = json_response['data']['responses'].map { |r| r['id'] }
      expect(response_ids).to include(recent_response.id)
      expect(response_ids).not_to include(old_response.id)
    end

    it 'includes pagination metadata' do
      get :index, params: { form_id: form.id }

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['data']['pagination']).to be_present
      expect(json_response['data']['pagination']).to have_key('current_page')
      expect(json_response['data']['pagination']).to have_key('total_count')
    end

    it 'includes summary statistics' do
      get :index, params: { form_id: form.id }

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['data']['summary']).to be_present
      expect(json_response['data']['summary']).to have_key('total_responses')
      expect(json_response['data']['summary']).to have_key('completion_rate')
    end
  end

  describe 'GET #show' do
    it 'returns the response details' do
      get :show, params: { form_id: form.id, id: form_response.id }

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['data']['response']['id']).to eq(form_response.id)
    end

    it 'returns 404 for non-existent response' do
      get :show, params: { form_id: form.id, id: 'non-existent' }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for response from different form' do
      other_form = create(:form, user: user)
      other_response = create(:form_response, form: other_form)

      get :show, params: { form_id: form.id, id: other_response.id }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        form_id: form.id,
        response: {
          referrer_url: 'https://example.com',
          utm_parameters: { utm_source: 'google' }
        }
      }
    end

    it 'creates a new response' do
      expect {
        post :create, params: valid_params
      }.to change(FormResponse, :count).by(1)

      expect(response).to have_http_status(:created)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['data']['response']).to be_present
    end

    it 'sets API-specific attributes' do
      post :create, params: valid_params

      created_response = FormResponse.last
      expect(created_response.session_id).to start_with('api_')
      expect(created_response.ip_address).to be_present
      expect(created_response.user_agent).to be_present
    end

    it 'returns validation errors for invalid data' do
      # Create a response that will fail validation
      allow_any_instance_of(FormResponse).to receive(:save).and_return(false)
      allow_any_instance_of(FormResponse).to receive(:errors).and_return(
        double(full_messages: ['Validation failed'])
      )

      post :create, params: { form_id: form.id, response: { referrer_url: 'test' } }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH #update' do
    it 'updates the response' do
      patch :update, params: {
        form_id: form.id,
        id: form_response.id,
        response: { referrer_url: 'https://updated.com' }
      }

      expect(response).to have_http_status(:ok)
      form_response.reload
      expect(form_response.referrer_url).to eq('https://updated.com')
    end

    it 'returns validation errors for invalid data' do
      # Create the response first
      response_id = form_response.id
      
      # Mock validation failure
      allow_any_instance_of(FormResponse).to receive(:update).and_return(false)

      patch :update, params: {
        form_id: form.id,
        id: response_id,
        response: { referrer_url: 'invalid' }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the response' do
      delete :destroy, params: { form_id: form.id, id: form_response.id }

      expect(response).to have_http_status(:ok)
      expect(FormResponse.exists?(form_response.id)).to be false
    end
  end

  describe 'POST #submit_answer' do
    let(:answer_params) do
      {
        form_id: form.id,
        id: form_response.id,
        question_id: question.id,
        answer: {
          value: 'Test answer',
          started_at: 1.minute.ago.iso8601,
          completed_at: Time.current.iso8601
        }
      }
    end

    it 'submits an answer successfully' do
      post :submit_answer, params: answer_params

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['data']['question_response']).to be_present
    end

    it 'creates a question response record' do
      expect {
        post :submit_answer, params: answer_params
      }.to change(QuestionResponse, :count).by(1)

      question_response = QuestionResponse.last
      expect(question_response.form_response).to eq(form_response)
      expect(question_response.form_question).to eq(question)
      expect(question_response.answer_data['value']).to eq('Test answer')
    end

    it 'calculates response time' do
      post :submit_answer, params: answer_params

      question_response = QuestionResponse.last
      expect(question_response.response_time_ms).to be > 0
    end

    it 'returns validation errors for invalid answer' do
      question.update!(required: true)
      
      post :submit_answer, params: {
        form_id: form.id,
        id: form_response.id,
        question_id: question.id,
        answer: { value: '' }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be false
      expect(json_response['errors']).to include('Answer is required')
    end

    it 'returns 404 for non-existent question' do
      post :submit_answer, params: {
        form_id: form.id,
        id: form_response.id,
        question_id: 'non-existent',
        answer: { value: 'Test' }
      }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #complete' do
    context 'when response can be completed' do
      before do
        allow_any_instance_of(FormResponse).to receive(:can_be_completed?).and_return(true)
        allow_any_instance_of(FormResponse).to receive(:mark_completed!).and_return(true)
      end

      it 'marks the response as completed' do
        post :complete, params: { form_id: form.id, id: form_response.id }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
      end
    end

    context 'when response cannot be completed' do
      before do
        allow_any_instance_of(FormResponse).to receive(:can_be_completed?).and_return(false)
      end

      it 'returns an error' do
        post :complete, params: { form_id: form.id, id: form_response.id }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['code']).to eq('INCOMPLETE_RESPONSE')
      end
    end
  end

  describe 'POST #abandon' do
    it 'marks the response as abandoned' do
      post :abandon, params: { form_id: form.id, id: form_response.id }

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      
      form_response.reload
      expect(form_response.status).to eq('abandoned')
    end

    it 'accepts custom abandonment reason' do
      post :abandon, params: { 
        form_id: form.id, 
        id: form_response.id, 
        reason: 'timeout' 
      }

      expect(response).to have_http_status(:ok)
      
      form_response.reload
      expect(form_response.abandonment_reason).to eq('timeout')
    end
  end

  describe 'POST #resume' do
    context 'when response is paused' do
      before do
        form_response.update!(status: :paused)
      end

      it 'resumes the response' do
        post :resume, params: { form_id: form.id, id: form_response.id }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
      end
    end

    context 'when response is not paused' do
      it 'returns an error' do
        post :resume, params: { form_id: form.id, id: form_response.id }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['code']).to eq('INVALID_STATUS')
      end
    end
  end

  describe 'GET #analytics' do
    it 'returns analytics data' do
      get :analytics, params: { form_id: form.id }

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['data']).to have_key('summary')
      expect(json_response['data']).to have_key('trends')
      expect(json_response['data']).to have_key('completion_funnel')
      expect(json_response['data']).to have_key('question_analytics')
    end

    it 'accepts period parameter' do
      get :analytics, params: { form_id: form.id, period: 7 }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #export' do
    it 'returns export information' do
      get :export, params: { form_id: form.id }

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['data']).to have_key('download_url')
      expect(json_response['data']).to have_key('filename')
      expect(json_response['data']).to have_key('expires_at')
    end

    it 'accepts format parameter' do
      get :export, params: { form_id: form.id, format: 'json' }

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['data']['format']).to eq('json')
    end
  end

  describe 'GET #answers' do
    let!(:question_response) { create(:question_response, form_response: form_response, form_question: question) }

    it 'returns all answers for the response' do
      get :answers, params: { form_id: form.id, id: form_response.id }

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['data']['answers']).to be_an(Array)
      expect(json_response['data']['answers'].length).to eq(1)
    end

    it 'includes response summary' do
      get :answers, params: { form_id: form.id, id: form_response.id }

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['data']['response_summary']).to be_present
    end
  end

  describe 'authentication and authorization' do
    context 'without API token' do
      before do
        request.headers['Authorization'] = nil
      end

      it 'returns unauthorized' do
        get :index, params: { form_id: form.id }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid API token' do
      before do
        request.headers['Authorization'] = 'Bearer invalid_token'
      end

      it 'returns unauthorized' do
        get :index, params: { form_id: form.id }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'accessing another user\'s form' do
      let(:other_user) { create(:user) }
      let(:other_form) { create(:form, user: other_user) }

      it 'returns not found' do
        get :index, params: { form_id: other_form.id }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'error handling' do
    it 'handles ActiveRecord::RecordNotFound' do
      get :show, params: { form_id: form.id, id: 'non-existent' }

      expect(response).to have_http_status(:not_found)
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to eq('Resource not found')
    end

    it 'handles validation errors' do
      allow_any_instance_of(FormResponse).to receive(:save).and_return(false)
      allow_any_instance_of(FormResponse).to receive(:errors).and_return(
        double(full_messages: ['Validation failed'])
      )

      post :create, params: { form_id: form.id, response: { referrer_url: 'test' } }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end