# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::FormsController, type: :controller do
  let(:user) { create(:user) }
  let(:api_token) { create(:api_token, user: user) }
  let(:form) { create(:form, user: user) }
  let(:other_user) { create(:user) }
  let(:other_form) { create(:form, user: other_user) }

  before do
    request.headers['Authorization'] = "Bearer #{api_token.token}"
  end

  describe 'GET #index' do
    let!(:forms) { create_list(:form, 3, user: user) }

    context 'with valid authentication' do
      before { get :index }

      it 'returns success response' do
        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
      end

      it 'returns user forms' do
        expect(json_response['data']['forms']).to be_an(Array)
        expect(json_response['data']['forms'].length).to eq(3)
      end

      it 'includes pagination metadata' do
        expect(json_response['data']['pagination']).to include(
          'current_page', 'per_page', 'total_pages', 'total_count'
        )
      end
    end

    context 'with search parameters' do
      let!(:matching_form) { create(:form, user: user, name: 'Contact Form') }
      let!(:non_matching_form) { create(:form, user: user, name: 'Survey Form') }

      before { get :index, params: { query: 'Contact' } }

      it 'filters forms by query' do
        expect(json_response['data']['forms'].length).to eq(1)
        expect(json_response['data']['forms'].first['name']).to eq('Contact Form')
      end
    end

    context 'with status filter' do
      let!(:published_form) { create(:form, user: user, status: 'published') }
      let!(:draft_form) { create(:form, user: user, status: 'draft') }

      before { get :index, params: { status: 'published' } }

      it 'filters forms by status' do
        expect(json_response['data']['forms'].length).to eq(1)
        expect(json_response['data']['forms'].first['status']).to eq('published')
      end
    end

    context 'without authentication' do
      before do
        request.headers['Authorization'] = nil
        get :index
      end

      it 'returns unauthorized' do
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']).to eq('Authentication required')
      end
    end
  end

  describe 'GET #show' do
    context 'with valid form' do
      before { get :show, params: { id: form.id } }

      it 'returns success response' do
        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
      end

      it 'returns form data' do
        expect(json_response['data']['form']['id']).to eq(form.id)
        expect(json_response['data']['form']['name']).to eq(form.name)
      end

      it 'includes questions and analytics' do
        expect(json_response['data']['form']).to have_key('questions')
        expect(json_response['data']['form']).to have_key('analytics')
      end
    end

    context 'with non-existent form' do
      before { get :show, params: { id: 'non-existent' } }

      it 'returns not found' do
        expect(response).to have_http_status(:not_found)
        expect(json_response['error']).to eq('Resource not found')
      end
    end

    context 'with unauthorized form' do
      before { get :show, params: { id: other_form.id } }

      it 'returns unauthorized' do
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']).to eq('Unauthorized')
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        form: {
          name: 'New Form',
          description: 'A new form',
          category: 'general'
        }
      }
    end

    context 'with valid parameters' do
      before { post :create, params: valid_params }

      it 'creates a new form' do
        expect(response).to have_http_status(:created)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Form created successfully')
      end

      it 'returns form data' do
        expect(json_response['data']['form']['name']).to eq('New Form')
        expect(json_response['data']['form']['description']).to eq('A new form')
      end
    end

    context 'with invalid parameters' do
      before { post :create, params: { form: { name: '' } } }

      it 'returns validation errors' do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to eq('Unprocessable entity')
      end
    end

    context 'with AI enabled' do
      let(:ai_params) do
        valid_params.deep_merge(
          form: {
            ai_enabled: true,
            ai_configuration: { enabled: true, features: ['response_analysis'] }
          }
        )
      end

      before do
        allow(Forms::WorkflowGenerationJob).to receive(:perform_later)
        post :create, params: ai_params
      end

      it 'triggers workflow generation' do
        expect(Forms::WorkflowGenerationJob).to have_received(:perform_later)
      end
    end
  end

  describe 'PATCH #update' do
    let(:update_params) do
      {
        id: form.id,
        form: {
          name: 'Updated Form Name',
          description: 'Updated description'
        }
      }
    end

    context 'with valid parameters' do
      before { patch :update, params: update_params }

      it 'updates the form' do
        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Form updated successfully')
      end

      it 'returns updated form data' do
        expect(json_response['data']['form']['name']).to eq('Updated Form Name')
      end
    end

    context 'with invalid parameters' do
      before { patch :update, params: { id: form.id, form: { name: '' } } }

      it 'returns validation errors' do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to eq('Unprocessable entity')
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'with valid form' do
      before { delete :destroy, params: { id: form.id } }

      it 'deletes the form' do
        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Form deleted successfully')
      end

      it 'removes form from database' do
        expect(Form.find_by(id: form.id)).to be_nil
      end
    end
  end

  describe 'POST #publish' do
    let!(:question) { create(:form_question, form: form) }

    context 'with questions present' do
      before { post :publish, params: { id: form.id } }

      it 'publishes the form' do
        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Form published successfully')
      end

      it 'returns public URL' do
        expect(json_response['data']['public_url']).to be_present
      end

      it 'updates form status' do
        form.reload
        expect(form.status).to eq('published')
        expect(form.published_at).to be_present
      end
    end

    context 'without questions' do
      let(:form_without_questions) { create(:form, user: user) }
      
      before { post :publish, params: { id: form_without_questions.id } }

      it 'returns validation error' do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Cannot publish form without questions')
      end
    end
  end

  describe 'POST #unpublish' do
    let(:published_form) { create(:form, user: user, status: 'published', published_at: Time.current) }

    before { post :unpublish, params: { id: published_form.id } }

    it 'unpublishes the form' do
      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Form unpublished successfully')
    end

    it 'updates form status' do
      published_form.reload
      expect(published_form.status).to eq('draft')
      expect(published_form.published_at).to be_nil
    end
  end

  describe 'POST #duplicate' do
    before do
      allow_any_instance_of(Forms::ManagementAgent).to receive(:duplicate_form)
        .and_return(create(:form, user: user, name: "#{form.name} (Copy)"))
    end

    context 'successful duplication' do
      before { post :duplicate, params: { id: form.id } }

      it 'duplicates the form' do
        expect(response).to have_http_status(:created)
        expect(json_response['success']).to be true
        expect(json_response['message']).to eq('Form duplicated successfully')
      end

      it 'returns duplicated form data' do
        expect(json_response['data']['form']['name']).to include('(Copy)')
      end
    end

    context 'duplication failure' do
      before do
        allow_any_instance_of(Forms::ManagementAgent).to receive(:duplicate_form)
          .and_raise(StandardError.new('Duplication failed'))
        post :duplicate, params: { id: form.id }
      end

      it 'returns error response' do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Duplication failed')
      end
    end
  end

  describe 'GET #analytics' do
    before do
      allow(form).to receive(:cached_analytics_summary).and_return({
        period: 30.days,
        views: 100,
        responses: 50,
        completions: 40,
        completion_rate: 80.0,
        avg_time: 120
      })
      get :analytics, params: { id: form.id }
    end

    it 'returns analytics data' do
      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']['summary']).to include('views', 'responses', 'completions')
    end

    it 'includes period information' do
      expect(json_response['data']['period']).to eq(30.days.to_i)
    end
  end

  describe 'GET #export' do
    before do
      allow_any_instance_of(Forms::ManagementAgent).to receive(:export_form_data)
        .and_return({
          download_url: 'https://example.com/export.csv',
          filename: 'form_export.csv',
          expires_at: 1.hour.from_now
        })
      get :export, params: { id: form.id, format: 'csv' }
    end

    it 'returns export data' do
      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']['download_url']).to be_present
      expect(json_response['data']['filename']).to eq('form_export.csv')
    end
  end

  describe 'GET #preview' do
    before { get :preview, params: { id: form.id } }

    it 'returns preview data' do
      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']['form']).to be_present
      expect(json_response['data']['preview_url']).to be_present
    end
  end

  describe 'POST #test_ai_feature' do
    let(:ai_form) do
      create(:form, user: user, ai_enabled: true, ai_configuration: { 
        enabled: true, 
        features: ['response_analysis'] 
      })
    end

    context 'with AI enabled form' do
      before do
        # Mock the workflow to avoid SuperAgent framework issues during testing
        allow_any_instance_of(Api::V1::FormsController).to receive(:test_response_analysis)
          .and_return({
            sentiment: 'positive',
            confidence: 0.85,
            insights: ['Customer is satisfied']
          })
        
        post :test_ai_feature, params: {
          id: ai_form.id,
          feature_type: 'response_analysis',
          test_data: { sample_answer: 'Great product!' }
        }
      end

      it 'returns AI test results' do
        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['data']['result']).to include('sentiment', 'confidence')
      end
    end

    context 'with AI disabled form' do
      before do
        post :test_ai_feature, params: {
          id: form.id,
          feature_type: 'response_analysis'
        }
      end

      it 'returns error for non-AI form' do
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('AI features not enabled')
      end
    end

    context 'with invalid feature type' do
      before do
        post :test_ai_feature, params: {
          id: ai_form.id,
          feature_type: 'invalid_feature'
        }
      end

      it 'returns error for invalid feature' do
        expect(response).to have_http_status(:bad_request)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('Unknown AI feature type')
      end
    end
  end

  describe 'GET #embed_code' do
    before { get :embed_code, params: { id: form.id } }

    it 'returns embed code' do
      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']['embed_code']).to include('<iframe')
      expect(json_response['data']['public_url']).to be_present
    end
  end

  describe 'GET #templates' do
    before { get :templates }

    it 'returns templates list' do
      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']['templates']).to be_an(Array)
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end