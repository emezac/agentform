# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::PaymentAnalyticsController, type: :controller do
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  before do
    sign_in admin_user
  end

  describe 'GET #index' do
    let!(:analytics_data) do
      create_list(:payment_analytic, 5, :template_interaction, user: regular_user)
    end

    it 'returns successful response' do
      get :index
      
      expect(response).to have_http_status(:success)
    end

    it 'assigns metrics' do
      get :index
      
      expect(assigns(:metrics)).to be_present
      expect(assigns(:metrics)).to include(:setup_completion_rate, :template_interaction_stats)
    end

    it 'assigns recent events' do
      get :index
      
      expect(assigns(:recent_events)).to be_present
      expect(assigns(:recent_events).count).to eq(5)
    end

    context 'with date range parameters' do
      it 'uses custom date range' do
        start_date = 7.days.ago.to_date
        end_date = Date.current
        
        get :index, params: { start_date: start_date, end_date: end_date }
        
        expect(assigns(:date_range)).to eq(start_date..end_date.end_of_day)
      end
    end

    context 'when user is not admin' do
      before do
        sign_in regular_user
      end

      it 'redirects to root path' do
        get :index
        
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'GET #export' do
    let!(:analytics_data) do
      create_list(:payment_analytic, 3, :setup_completed, user: regular_user)
    end

    context 'CSV export' do
      it 'returns CSV data' do
        get :export, format: :csv
        
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('text/csv')
        expect(response.headers['Content-Disposition']).to include('attachment')
      end

      it 'includes correct CSV headers' do
        get :export, format: :csv
        
        csv_content = response.body
        expect(csv_content).to include('Event Type,User ID,User Tier,Timestamp,Context')
      end

      it 'includes analytics data in CSV' do
        get :export, format: :csv
        
        csv_content = response.body
        expect(csv_content).to include('payment_setup_completed')
        expect(csv_content).to include(regular_user.id)
      end
    end

    context 'JSON export' do
      it 'returns JSON metrics' do
        get :export, format: :json
        
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('application/json')
      end

      it 'includes metrics in JSON response' do
        get :export, format: :json
        
        json_response = JSON.parse(response.body)
        expect(json_response).to include('setup_completion_rate', 'template_interaction_stats')
      end
    end

    context 'with date range parameters' do
      it 'exports data for specified date range' do
        start_date = 7.days.ago.to_date
        end_date = Date.current
        
        get :export, format: :csv, params: { start_date: start_date, end_date: end_date }
        
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user is not admin' do
      before do
        sign_in regular_user
      end

      it 'redirects to root path' do
        get :export, format: :csv
        
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'CSV generation' do
    let!(:analytic) do
      create(:payment_analytic, :validation_error, 
             user: regular_user,
             context: { error_type: 'stripe_not_configured' })
    end

    it 'generates valid CSV format' do
      get :export, format: :csv
      
      csv_content = response.body
      lines = csv_content.split("\n")
      
      # Check header
      expect(lines.first).to eq('Event Type,User ID,User Tier,Timestamp,Context')
      
      # Check data row
      data_line = lines[1]
      expect(data_line).to include('payment_validation_errors')
      expect(data_line).to include(regular_user.id)
    end

    it 'handles special characters in context' do
      analytic.update!(context: { message: 'Error with "quotes" and, commas' })
      
      get :export, format: :csv
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('payment_validation_errors')
    end
  end

  describe 'authorization' do
    context 'when user is not signed in' do
      before do
        sign_out admin_user
      end

      it 'redirects to sign in' do
        get :index
        
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when user is not admin' do
      before do
        sign_in regular_user
      end

      it 'redirects to root path for index' do
        get :index
        
        expect(response).to redirect_to(root_path)
      end

      it 'redirects to root path for export' do
        get :export, format: :csv
        
        expect(response).to redirect_to(root_path)
      end
    end
  end
end