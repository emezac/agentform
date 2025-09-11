# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SafePagination, type: :controller do
  controller(ApplicationController) do
    include SafePagination
    
    def index
      @users = safe_paginate(User.all, page: params[:page], per_page: params[:per_page])
      render json: { users: @users.map(&:id), pagination: pagination_info }
    end
    
    private
    
    def pagination_info
      {
        current_page: @users.current_page,
        total_pages: @users.total_pages,
        total_count: @users.total_count,
        next_page: @users.next_page,
        prev_page: @users.prev_page
      }
    end
  end

  let!(:users) { create_list(:user, 25) }

  before do
    routes.draw { get 'index' => 'anonymous#index' }
  end

  describe '#safe_paginate' do
    context 'when Kaminari is available' do
      before do
        # Ensure Kaminari is loaded
        require 'kaminari' if defined?(Kaminari)
      end

      it 'uses Kaminari pagination when available' do
        allow(Rails.logger).to receive(:debug)
        
        get :index, params: { page: 2, per_page: 10 }
        
        expect(Rails.logger).to have_received(:debug).with(/Using Kaminari pagination/)
        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['pagination']['current_page']).to eq(2)
        expect(json_response['pagination']['total_pages']).to eq(3)
        expect(json_response['users'].size).to eq(10)
      end

      it 'handles first page correctly' do
        get :index, params: { page: 1, per_page: 10 }
        
        json_response = JSON.parse(response.body)
        expect(json_response['pagination']['current_page']).to eq(1)
        expect(json_response['pagination']['prev_page']).to be_nil
        expect(json_response['pagination']['next_page']).to eq(2)
      end

      it 'handles last page correctly' do
        get :index, params: { page: 3, per_page: 10 }
        
        json_response = JSON.parse(response.body)
        expect(json_response['pagination']['current_page']).to eq(3)
        expect(json_response['pagination']['next_page']).to be_nil
        expect(json_response['pagination']['prev_page']).to eq(2)
      end
    end

    context 'when Kaminari is not available' do
      before do
        # Mock Kaminari as not available
        allow(controller).to receive(:kaminari_available?).and_return(false)
        allow(Rails.logger).to receive(:warn)
      end

      it 'uses fallback pagination' do
        get :index, params: { page: 2, per_page: 10 }
        
        expect(Rails.logger).to have_received(:warn).with(/Using fallback pagination/)
        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['pagination']['current_page']).to eq(2)
        expect(json_response['pagination']['total_pages']).to eq(3)
        expect(json_response['users'].size).to eq(10)
      end

      it 'calculates pagination metadata correctly' do
        get :index, params: { page: 1, per_page: 10 }
        
        json_response = JSON.parse(response.body)
        pagination = json_response['pagination']
        
        expect(pagination['current_page']).to eq(1)
        expect(pagination['total_pages']).to eq(3)
        expect(pagination['total_count']).to eq(25)
        expect(pagination['next_page']).to eq(2)
        expect(pagination['prev_page']).to be_nil
      end

      it 'handles empty results' do
        User.destroy_all
        
        get :index, params: { page: 1, per_page: 10 }
        
        json_response = JSON.parse(response.body)
        pagination = json_response['pagination']
        
        expect(pagination['current_page']).to eq(1)
        expect(pagination['total_pages']).to eq(0)
        expect(pagination['total_count']).to eq(0)
        expect(json_response['users']).to be_empty
      end

      context 'with Sentry available' do
        before do
          stub_const('Sentry', double('Sentry'))
          allow(Sentry).to receive(:capture_message)
        end

        it 'reports fallback usage to Sentry' do
          get :index, params: { page: 2, per_page: 10 }
          
          expect(Sentry).to have_received(:capture_message).with(
            'Pagination fallback used',
            hash_including(
              level: :warning,
              extra: hash_including(
                page: 2,
                per_page: 10,
                controller: 'AnonymousController'
              )
            )
          )
        end
      end
    end

    describe 'parameter normalization' do
      before do
        allow(controller).to receive(:kaminari_available?).and_return(false)
        allow(Rails.logger).to receive(:warn)
      end

      it 'normalizes invalid page numbers' do
        get :index, params: { page: 0, per_page: 10 }
        
        json_response = JSON.parse(response.body)
        expect(json_response['pagination']['current_page']).to eq(1)
      end

      it 'normalizes negative page numbers' do
        get :index, params: { page: -5, per_page: 10 }
        
        json_response = JSON.parse(response.body)
        expect(json_response['pagination']['current_page']).to eq(1)
      end

      it 'normalizes invalid per_page values' do
        get :index, params: { page: 1, per_page: 0 }
        
        json_response = JSON.parse(response.body)
        expect(json_response['users'].size).to eq(20) # Default per_page
      end

      it 'limits excessive per_page values' do
        get :index, params: { page: 1, per_page: 1000 }
        
        json_response = JSON.parse(response.body)
        expect(json_response['users'].size).to eq(25) # All users, but limited to 100 max
      end

      it 'handles nil parameters' do
        get :index
        
        json_response = JSON.parse(response.body)
        pagination = json_response['pagination']
        
        expect(pagination['current_page']).to eq(1)
        expect(json_response['users'].size).to eq(20) # Default per_page
      end
    end

    describe 'pagination metadata methods' do
      before do
        allow(controller).to receive(:kaminari_available?).and_return(false)
        allow(Rails.logger).to receive(:warn)
      end

      it 'provides all required pagination methods' do
        get :index, params: { page: 2, per_page: 10 }
        
        users = controller.instance_variable_get(:@users)
        
        expect(users).to respond_to(:current_page)
        expect(users).to respond_to(:total_pages)
        expect(users).to respond_to(:total_count)
        expect(users).to respond_to(:next_page)
        expect(users).to respond_to(:prev_page)
        expect(users).to respond_to(:first_page?)
        expect(users).to respond_to(:last_page?)
        expect(users).to respond_to(:offset_value)
        expect(users).to respond_to(:limit_value)
        expect(users).to respond_to(:total_entries) # Compatibility alias
      end

      it 'calculates first_page? correctly' do
        get :index, params: { page: 1, per_page: 10 }
        users = controller.instance_variable_get(:@users)
        expect(users.first_page?).to be true

        get :index, params: { page: 2, per_page: 10 }
        users = controller.instance_variable_get(:@users)
        expect(users.first_page?).to be false
      end

      it 'calculates last_page? correctly' do
        get :index, params: { page: 3, per_page: 10 }
        users = controller.instance_variable_get(:@users)
        expect(users.last_page?).to be true

        get :index, params: { page: 2, per_page: 10 }
        users = controller.instance_variable_get(:@users)
        expect(users.last_page?).to be false
      end
    end
  end
end