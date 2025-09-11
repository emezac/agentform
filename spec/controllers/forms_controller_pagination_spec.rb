# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormsController, type: :controller do
  let(:user) { create(:user) }
  let(:form) { create(:form, user: user) }
  let!(:form_responses) { create_list(:form_response, 25, form: form) }

  before do
    sign_in user
  end

  describe 'GET #responses' do
    context 'with pagination working normally' do
      it 'paginates responses correctly' do
        get :responses, params: { id: form.id, page: 2, per_page: 10 }
        
        expect(response).to have_http_status(:success)
        expect(assigns(:responses)).to be_present
        expect(assigns(:responses).size).to eq(10)
        expect(assigns(:responses).current_page).to eq(2)
        expect(assigns(:responses).total_count).to eq(25)
      end

      it 'uses default per_page when not specified' do
        get :responses, params: { id: form.id, page: 1 }
        
        expect(response).to have_http_status(:success)
        expect(assigns(:responses).size).to eq(20) # Default per_page
      end

      it 'handles first page correctly' do
        get :responses, params: { id: form.id, page: 1, per_page: 10 }
        
        responses = assigns(:responses)
        expect(responses.current_page).to eq(1)
        expect(responses.first_page?).to be true
        expect(responses.prev_page).to be_nil
        expect(responses.next_page).to eq(2)
      end

      it 'handles last page correctly' do
        get :responses, params: { id: form.id, page: 3, per_page: 10 }
        
        responses = assigns(:responses)
        expect(responses.current_page).to eq(3)
        expect(responses.last_page?).to be true
        expect(responses.next_page).to be_nil
        expect(responses.prev_page).to eq(2)
      end
    end

    context 'when Kaminari is not available' do
      before do
        # Mock SafePagination to use fallback mode
        allow(controller).to receive(:kaminari_available?).and_return(false)
        allow(Rails.logger).to receive(:warn)
      end

      it 'still works with fallback pagination' do
        get :responses, params: { id: form.id, page: 2, per_page: 10 }
        
        expect(response).to have_http_status(:success)
        expect(assigns(:responses)).to be_present
        expect(assigns(:responses).size).to eq(10)
        expect(assigns(:responses).current_page).to eq(2)
        expect(Rails.logger).to have_received(:warn).with(/Using fallback pagination/)
      end

      it 'provides all necessary pagination metadata' do
        get :responses, params: { id: form.id, page: 1, per_page: 10 }
        
        responses = assigns(:responses)
        expect(responses).to respond_to(:current_page)
        expect(responses).to respond_to(:total_pages)
        expect(responses).to respond_to(:total_count)
        expect(responses).to respond_to(:next_page)
        expect(responses).to respond_to(:prev_page)
        expect(responses).to respond_to(:first_page?)
        expect(responses).to respond_to(:last_page?)
      end
    end

    context 'with invalid parameters' do
      before do
        allow(controller).to receive(:kaminari_available?).and_return(false)
        allow(Rails.logger).to receive(:warn)
      end

      it 'handles invalid page numbers gracefully' do
        get :responses, params: { id: form.id, page: 0, per_page: 10 }
        
        expect(response).to have_http_status(:success)
        expect(assigns(:responses).current_page).to eq(1)
      end

      it 'handles negative page numbers' do
        get :responses, params: { id: form.id, page: -5, per_page: 10 }
        
        expect(response).to have_http_status(:success)
        expect(assigns(:responses).current_page).to eq(1)
      end

      it 'handles excessive per_page values' do
        get :responses, params: { id: form.id, page: 1, per_page: 1000 }
        
        expect(response).to have_http_status(:success)
        # Should be limited to maximum allowed
        expect(assigns(:responses).size).to be <= 100
      end
    end

    context 'with empty results' do
      let(:empty_form) { create(:form, user: user) }

      before do
        allow(controller).to receive(:kaminari_available?).and_return(false)
        allow(Rails.logger).to receive(:warn)
      end

      it 'handles empty response sets' do
        get :responses, params: { id: empty_form.id, page: 1, per_page: 10 }
        
        expect(response).to have_http_status(:success)
        expect(assigns(:responses)).to be_empty
        expect(assigns(:responses).total_count).to eq(0)
        expect(assigns(:responses).total_pages).to eq(0)
      end
    end

    context 'CSV download functionality' do
      it 'is not affected by pagination changes' do
        get :responses, params: { id: form.id, format: :csv }
        
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('text/csv')
      end
    end

    context 'authorization' do
      let(:other_user) { create(:user) }
      let(:other_form) { create(:form, user: other_user) }

      it 'still enforces authorization with pagination' do
        expect {
          get :responses, params: { id: other_form.id, page: 1 }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context 'includes and ordering' do
      before do
        # Create responses with associated data
        form_responses.each do |response|
          create(:question_response, form_response: response)
        end
      end

      it 'maintains proper includes and ordering' do
        get :responses, params: { id: form.id, page: 1, per_page: 5 }
        
        responses = assigns(:responses)
        expect(responses).to be_present
        
        # Check that associations are loaded (no N+1 queries)
        expect { responses.each { |r| r.question_responses.to_a } }.not_to exceed_query_limit(1)
        
        # Check ordering (newest first)
        timestamps = responses.map(&:created_at)
        expect(timestamps).to eq(timestamps.sort.reverse)
      end
    end
  end
end