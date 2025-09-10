# frozen_string_literal: true

require 'rails_helper'

# Create a test controller that inherits from Api::BaseController
class Api::TestController < Api::BaseController
  def index
    return unless authorize_token!(:test, :index)
    render_success({ message: 'Test successful' })
  end

  def show
    return unless authorize_token!(:test, :show)
    render json: { id: params[:id] }
  end

  def create
    return unless authorize_token!(:test, :create)
    render_created({ id: 123 })
  end

  def unauthorized_action
    raise Pundit::NotAuthorizedError
  end

  def not_found_action
    raise ActiveRecord::RecordNotFound
  end

  def validation_error_action
    user = User.new
    user.save! # This will raise ActiveRecord::RecordInvalid
  end
end

RSpec.describe Api::BaseController, type: :controller do
  controller(Api::TestController) do
    def index
      return unless authorize_token!(:test, :index)
      render_success({ message: 'Test successful' })
    end

    def show
      return unless authorize_token!(:test, :show)
      render json: { id: params[:id] }
    end

    def create
      return unless authorize_token!(:test, :create)
      render_created({ id: 123 })
    end

    def unauthorized_action
      raise Pundit::NotAuthorizedError
    end

    def not_found_action
      raise ActiveRecord::RecordNotFound
    end

    def validation_error_action
      user = User.new
      user.save! # This will raise ActiveRecord::RecordInvalid
    end
  end

  let(:user) { create(:user) }
  let(:api_token) { create(:api_token, user: user, permissions: { 'test' => ['index', 'show', 'create'] }) }

  before do
    routes.draw do
      get 'index' => 'api/test#index'
      get 'show/:id' => 'api/test#show'
      post 'create' => 'api/test#create'
      get 'unauthorized' => 'api/test#unauthorized_action'
      get 'not_found' => 'api/test#not_found_action'
      get 'validation_error' => 'api/test#validation_error_action'
    end
  end

  describe 'authentication' do
    context 'without token' do
      it 'returns authentication required error' do
        get :index
        
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']).to eq('Authentication required')
        expect(json_response['code']).to eq('AUTHENTICATION_REQUIRED')
      end
    end

    context 'with invalid token' do
      it 'returns invalid token error' do
        request.headers['Authorization'] = 'Bearer invalid_token'
        get :index
        
        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']).to eq('Invalid token')
        expect(json_response['code']).to eq('INVALID_TOKEN')
      end
    end

    context 'with valid token' do
      before do
        request.headers['Authorization'] = "Bearer #{api_token.token}"
      end

      it 'authenticates successfully' do
        get :index
        
        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['data']['message']).to eq('Test successful')
      end

      it 'sets current_user' do
        get :index
        
        expect(controller.current_user).to eq(user)
        expect(controller.current_api_token).to eq(api_token)
      end
    end

    context 'with Bearer prefix' do
      it 'handles Bearer prefix correctly' do
        request.headers['Authorization'] = "Bearer #{api_token.token}"
        get :index
        
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without Bearer prefix' do
      it 'handles token without Bearer prefix' do
        request.headers['Authorization'] = api_token.token
        get :index
        
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'authorization' do
    before do
      request.headers['Authorization'] = "Bearer #{api_token.token}"
    end

    context 'with sufficient permissions' do
      it 'allows access to permitted actions' do
        get :index
        expect(response).to have_http_status(:ok)
        
        get :show, params: { id: 1 }
        expect(response).to have_http_status(:ok)
        
        post :create
        expect(response).to have_http_status(:created)
      end
    end

    context 'with insufficient permissions' do
      let(:limited_token) { create(:api_token, user: user, permissions: { 'test' => ['index'] }) }
      
      before do
        request.headers['Authorization'] = "Bearer #{limited_token.token}"
      end

      it 'denies access to unpermitted actions' do
        post :create
        
        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']).to eq('Insufficient permissions')
        expect(json_response['code']).to eq('INSUFFICIENT_PERMISSIONS')
        expect(json_response['required_permission']).to eq('test:create')
      end
    end
  end

  describe 'error handling' do
    before do
      request.headers['Authorization'] = "Bearer #{api_token.token}"
    end

    it 'handles Pundit::NotAuthorizedError' do
      get :unauthorized_action
      
      expect(response).to have_http_status(:unauthorized)
      expect(json_response['error']).to eq('Unauthorized')
      expect(json_response['code']).to eq('UNAUTHORIZED')
    end

    it 'handles ActiveRecord::RecordNotFound' do
      get :not_found_action
      
      expect(response).to have_http_status(:not_found)
      expect(json_response['error']).to eq('Resource not found')
      expect(json_response['code']).to eq('NOT_FOUND')
    end

    it 'handles ActiveRecord::RecordInvalid' do
      get :validation_error_action
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error']).to eq('Unprocessable entity')
      expect(json_response['code']).to eq('VALIDATION_ERROR')
      expect(json_response['errors']).to be_an(Array)
    end
  end

  describe 'response helpers' do
    before do
      request.headers['Authorization'] = "Bearer #{api_token.token}"
    end

    it 'renders success responses correctly' do
      get :index
      
      expect(response).to have_http_status(:ok)
      expect(json_response['success']).to be true
      expect(json_response['data']).to be_present
    end

    it 'renders created responses correctly' do
      post :create
      
      expect(response).to have_http_status(:created)
      expect(json_response['success']).to be true
      expect(json_response['message']).to eq('Resource created successfully')
      expect(json_response['data']['id']).to eq(123)
    end
  end

  describe 'format handling' do
    before do
      request.headers['Authorization'] = "Bearer #{api_token.token}"
    end

    it 'defaults to JSON format' do
      get :index
      expect(request.format.symbol).to eq(:json)
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end