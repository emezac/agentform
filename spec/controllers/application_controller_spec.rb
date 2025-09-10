# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  controller do
    def index
      render json: { message: 'success' }
    end

    def show
      authorize User.new
      render json: { message: 'authorized' }
    end

    def create
      raise ActiveRecord::RecordNotFound, 'Test not found'
    end

    def update
      raise Pundit::NotAuthorizedError, 'Test unauthorized'
    end

    def destroy
      raise ActionController::ParameterMissing, 'Test parameter missing'
    end
  end

  let(:user) { create(:user) }

  before do
    routes.draw do
      get 'index' => 'anonymous#index'
      get 'show' => 'anonymous#show'
      post 'create' => 'anonymous#create'
      patch 'update' => 'anonymous#update'
      delete 'destroy' => 'anonymous#destroy'
    end
  end

  describe 'authentication' do
    context 'when user is not authenticated' do
      it 'redirects to sign in' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when user is authenticated' do
      before { sign_in user }

      it 'allows access' do
        get :index
        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)['message']).to eq('success')
      end

      it 'sets current user context' do
        get :index
        expect(Current.user).to eq(user)
        expect(Current.request_id).to be_present
      end
    end
  end

  describe 'error handling' do
    before { sign_in user }

    describe 'ActiveRecord::RecordNotFound' do
      it 'renders 404 for JSON requests' do
        post :create, format: :json
        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)['error']).to eq('Resource not found')
      end
    end

    describe 'Pundit::NotAuthorizedError' do
      it 'renders 401 for JSON requests' do
        patch :update, format: :json
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to eq('Unauthorized')
      end
    end

    describe 'ActionController::ParameterMissing' do
      it 'renders 400 for JSON requests' do
        delete :destroy, format: :json
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['error']).to eq('Bad request')
      end
    end
  end

  describe 'helper methods' do
    before { sign_in user }

    describe '#require_admin!' do
      context 'when user is admin' do
        let(:user) { create(:user, role: 'admin') }

        it 'allows access' do
          expect { controller.send(:require_admin!) }.not_to raise_error
        end
      end

      context 'when user is not admin' do
        it 'renders unauthorized' do
          expect(controller).to receive(:render_unauthorized)
          controller.send(:require_admin!)
        end
      end
    end

    describe '#require_premium!' do
      context 'when user is premium' do
        let(:user) { create(:user, role: 'premium') }

        it 'allows access' do
          expect { controller.send(:require_premium!) }.not_to raise_error
        end
      end

      context 'when user is admin' do
        let(:user) { create(:user, role: 'admin') }

        it 'allows access' do
          expect { controller.send(:require_premium!) }.not_to raise_error
        end
      end

      context 'when user is regular user' do
        it 'renders unauthorized' do
          expect(controller).to receive(:render_unauthorized)
          controller.send(:require_premium!)
        end
      end
    end
  end

  describe 'Pundit integration' do
    before { sign_in user }

    it 'includes Pundit::Authorization' do
      expect(controller.class.ancestors).to include(Pundit::Authorization)
    end

    it 'sets pundit_user to current_user' do
      get :index
      expect(controller.send(:pundit_user)).to eq(user)
    end
  end
end