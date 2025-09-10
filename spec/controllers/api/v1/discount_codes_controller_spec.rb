require 'rails_helper'

RSpec.describe Api::V1::DiscountCodesController, type: :controller do
  let(:user) { create(:user) }
  let!(:discount_code) { create(:discount_code, code: 'SAVE20', discount_percentage: 20, active: true) }

  before do
    sign_in user
  end

  describe 'POST #validate' do
    context 'with valid discount code' do
      it 'returns discount information for monthly billing' do
        post :validate, params: { code: 'SAVE20', billing_cycle: 'monthly' }

        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be true
        expect(json_response['discount_code']['code']).to eq('SAVE20')
        expect(json_response['discount_code']['discount_percentage']).to eq(20)
        expect(json_response['pricing']['original_amount']).to eq(2900) # $29.00 in cents
        expect(json_response['pricing']['discount_amount']).to eq(580)  # 20% of $29.00
        expect(json_response['pricing']['final_amount']).to eq(2320)    # $29.00 - $5.80
      end

      it 'returns discount information for yearly billing' do
        post :validate, params: { code: 'SAVE20', billing_cycle: 'yearly' }

        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be true
        expect(json_response['pricing']['original_amount']).to eq(29000) # $290.00 in cents
        expect(json_response['pricing']['discount_amount']).to eq(5800)  # 20% of $290.00
        expect(json_response['pricing']['final_amount']).to eq(23200)    # $290.00 - $58.00
      end

      it 'handles case insensitive codes' do
        post :validate, params: { code: 'save20', billing_cycle: 'monthly' }

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be true
      end

      it 'includes usage statistics in response' do
        post :validate, params: { code: 'SAVE20', billing_cycle: 'monthly' }

        json_response = JSON.parse(response.body)
        expect(json_response['discount_code']).to have_key('remaining_uses')
        expect(json_response['discount_code']).to have_key('expires_at')
        expect(json_response['discount_code']).to have_key('usage_percentage')
      end

      it 'handles codes with unlimited usage' do
        discount_code.update!(max_usage_count: nil)
        
        post :validate, params: { code: 'SAVE20', billing_cycle: 'monthly' }

        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be true
        expect(json_response['discount_code']['remaining_uses']).to be_nil
      end

      it 'returns user eligibility information' do
        post :validate, params: { code: 'SAVE20', billing_cycle: 'monthly' }

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('user_eligible')
        expect(json_response['user_eligible']).to be true
      end
    end

    context 'with invalid discount code' do
      it 'returns error for non-existent code' do
        post :validate, params: { code: 'INVALID', billing_cycle: 'monthly' }

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be false
        expect(json_response['error']).to include('Invalid discount code')
      end

      it 'returns error for inactive code' do
        discount_code.update!(active: false)
        
        post :validate, params: { code: 'SAVE20', billing_cycle: 'monthly' }

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be false
        expect(json_response['error']).to include('no longer active')
      end

      it 'returns error for expired code' do
        discount_code.update!(expires_at: 1.day.ago)
        
        post :validate, params: { code: 'SAVE20', billing_cycle: 'monthly' }

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be false
        expect(json_response['error']).to include('expired')
      end

      it 'returns error for exhausted code' do
        discount_code.update!(max_usage_count: 1, current_usage_count: 1)
        
        post :validate, params: { code: 'SAVE20', billing_cycle: 'monthly' }

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be false
        expect(json_response['error']).to include('usage limit')
      end

      it 'returns error for user who already used a discount' do
        user.update!(discount_code_used: true)
        
        post :validate, params: { code: 'SAVE20', billing_cycle: 'monthly' }

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be false
        expect(json_response['error']).to include('already used a discount code. Each account can only use one discount code.')
      end

      it 'returns error for suspended user' do
        user.update!(suspended_at: 1.day.ago, suspended_reason: 'Policy violation')
        
        post :validate, params: { code: 'SAVE20', billing_cycle: 'monthly' }

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be false
        expect(json_response['error']).to include('suspended and cannot use discount codes. Please contact support.')
      end

      it 'returns error for premium user' do
        user.update!(subscription_tier: 'premium')
        
        post :validate, params: { code: 'SAVE20', billing_cycle: 'monthly' }

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be false
        expect(json_response['error']).to include('Premium users cannot use discount codes on additional subscriptions.')
      end
    end

    context 'with missing parameters' do
      it 'returns error for missing code' do
        post :validate, params: { billing_cycle: 'monthly' }

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be false
      end
    end

    context 'when user is not authenticated' do
      before do
        sign_out user
      end

      it 'returns unauthorized status' do
        post :validate, params: { code: 'SAVE20', billing_cycle: 'monthly' }

        expect(response).to have_http_status(:unauthorized)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Authentication required')
      end
    end
  end

  describe 'GET #check_eligibility' do
    context 'when user is eligible' do
      it 'returns eligibility status' do
        get :check_eligibility

        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['eligible']).to be true
        expect(json_response['reasons']).to be_empty
      end
    end

    context 'when user is ineligible' do
      before { user.update!(discount_code_used: true) }

      it 'returns ineligibility reasons' do
        get :check_eligibility

        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['eligible']).to be false
        expect(json_response['reasons']).to include('User has already used a discount code')
      end
    end

    context 'when user is suspended' do
      before { user.update!(suspended_at: 1.day.ago, suspended_reason: 'Policy violation') }

      it 'returns suspension information' do
        get :check_eligibility

        json_response = JSON.parse(response.body)
        expect(json_response['eligible']).to be false
        expect(json_response['reasons']).to include('User account is suspended')
      end
    end
  end

  describe 'POST #apply' do
    let(:apply_params) do
      {
        code: 'SAVE20',
        billing_cycle: 'monthly',
        subscription_details: {
          subscription_id: 'sub_123456789',
          original_amount: 2900,
          discount_amount: 580,
          final_amount: 2320
        }
      }
    end

    context 'with valid application' do
      it 'records discount usage' do
        expect {
          post :apply, params: apply_params
        }.to change(DiscountCodeUsage, :count).by(1)

        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['usage_id']).to be_present
      end

      it 'updates user discount status' do
        post :apply, params: apply_params

        user.reload
        expect(user.discount_code_used?).to be true
      end

      it 'increments discount code usage count' do
        expect {
          post :apply, params: apply_params
        }.to change { discount_code.reload.current_usage_count }.by(1)
      end

      it 'deactivates code when usage limit reached' do
        discount_code.update!(max_usage_count: 1, current_usage_count: 0)
        
        post :apply, params: apply_params

        expect(discount_code.reload.active?).to be false
      end
    end

    context 'with invalid application' do
      it 'rejects application for ineligible user' do
        user.update!(discount_code_used: true)
        
        post :apply, params: apply_params

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to include('already used a discount code')
      end

      it 'rejects application with incorrect calculation' do
        invalid_params = apply_params.deep_dup
        invalid_params[:subscription_details][:final_amount] = 2000 # Incorrect calculation
        
        post :apply, params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('calculation is incorrect')
      end

      it 'handles concurrent usage attempts' do
        # Simulate race condition by making code unavailable
        discount_code.update!(active: false)
        
        post :apply, params: apply_params

        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('no longer active')
      end
    end
  end

  describe 'GET #usage_stats' do
    let!(:usage1) { create(:discount_code_usage, discount_code: discount_code, user: create(:user)) }
    let!(:usage2) { create(:discount_code_usage, discount_code: discount_code, user: create(:user)) }

    context 'when user is admin' do
      before { user.update!(role: 'admin') }

      it 'returns comprehensive usage statistics' do
        get :usage_stats, params: { code: 'SAVE20' }

        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['code']).to eq('SAVE20')
        expect(json_response['total_uses']).to eq(2)
        expect(json_response['revenue_impact']).to be_present
        expect(json_response['recent_usages']).to have(2).items
      end

      it 'includes user information in usage details' do
        get :usage_stats, params: { code: 'SAVE20' }

        json_response = JSON.parse(response.body)
        usage = json_response['recent_usages'].first
        expect(usage).to have_key('user_email')
        expect(usage).to have_key('used_at')
        expect(usage).to have_key('savings_amount')
      end
    end

    context 'when user is not admin' do
      it 'returns forbidden status' do
        get :usage_stats, params: { code: 'SAVE20' }

        expect(response).to have_http_status(:forbidden)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Admin privileges required')
      end
    end
  end

  describe 'rate limiting and security' do
    it 'implements rate limiting for validation attempts' do
      # Simulate multiple rapid requests
      10.times do
        post :validate, params: { code: 'INVALID', billing_cycle: 'monthly' }
      end

      # Next request should be rate limited
      post :validate, params: { code: 'INVALID', billing_cycle: 'monthly' }
      
      expect(response).to have_http_status(:too_many_requests)
      
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('rate limit')
    end

    it 'logs suspicious validation patterns' do
      expect(Rails.logger).to receive(:warn).with(/Suspicious discount code activity/)
      
      # Simulate rapid invalid attempts
      5.times do
        post :validate, params: { code: 'INVALID', billing_cycle: 'monthly' }
      end
    end

    it 'sanitizes input parameters' do
      malicious_code = '<script>alert("xss")</script>'
      
      post :validate, params: { code: malicious_code, billing_cycle: 'monthly' }

      expect(response).to have_http_status(:unprocessable_entity)
      
      # Response should not contain the malicious script
      expect(response.body).not_to include('<script>')
    end

    it 'validates billing cycle parameter' do
      post :validate, params: { code: 'SAVE20', billing_cycle: 'invalid' }

      expect(response).to have_http_status(:unprocessable_entity)
      
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('Invalid billing cycle')
    end
  end

  describe 'error handling' do
    it 'handles database connection errors gracefully' do
      allow(DiscountCode).to receive(:find_by).and_raise(ActiveRecord::ConnectionTimeoutError)
      
      post :validate, params: { code: 'SAVE20', billing_cycle: 'monthly' }

      expect(response).to have_http_status(:service_unavailable)
      
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('Service temporarily unavailable')
    end

    it 'handles service errors during application' do
      allow_any_instance_of(DiscountCodeService).to receive(:record_usage).and_raise(StandardError.new('Service error'))
      
      post :apply, params: {
        code: 'SAVE20',
        billing_cycle: 'monthly',
        subscription_details: {
          subscription_id: 'sub_123',
          original_amount: 2900,
          discount_amount: 580,
          final_amount: 2320
        }
      }

      expect(response).to have_http_status(:internal_server_error)
      
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('Internal server error')
    end

    it 'validates required parameters' do
      post :validate, params: { billing_cycle: 'monthly' } # Missing code

      expect(response).to have_http_status(:bad_request)
      
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('Missing required parameter: code')
    end
  end

  describe 'API versioning and compatibility' do
    it 'includes API version in response headers' do
      post :validate, params: { code: 'SAVE20', billing_cycle: 'monthly' }

      expect(response.headers['API-Version']).to eq('v1')
    end

    it 'maintains backward compatibility' do
      # Test that old client requests still work
      post :validate, params: { 
        discount_code: 'SAVE20',  # Old parameter name
        billing_cycle: 'monthly' 
      }

      expect(response).to have_http_status(:success)
    end

    it 'supports content negotiation' do
      request.headers['Accept'] = 'application/json'
      
      post :validate, params: { code: 'SAVE20', billing_cycle: 'monthly' }

      expect(response.content_type).to include('application/json')
    end
  end
  end
end