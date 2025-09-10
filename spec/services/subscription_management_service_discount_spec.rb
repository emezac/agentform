require 'rails_helper'

RSpec.describe SubscriptionManagementService, type: :service do
  let(:user) { create(:user, subscription_tier: 'freemium') }
  let!(:discount_code) { create(:discount_code, code: 'WELCOME20', discount_percentage: 20, active: true) }
  let(:service) { described_class.new(user: user) }

  describe '#create_subscription with discount codes' do
    let(:success_url) { 'https://example.com/success' }
    let(:cancel_url) { 'https://example.com/cancel' }

    before do
      # Mock Stripe client
      @stripe_client_mock = double('Stripe::StripeClient')
      allow(Stripe::StripeClient).to receive(:new).and_return(@stripe_client_mock)

      # Mock Stripe customer creation
      stripe_customer = double('Stripe::Customer', id: 'cus_test123')
      allow(@stripe_client_mock).to receive_message_chain(:customers, :create)
        .and_return(stripe_customer)
      allow(@stripe_client_mock).to receive_message_chain(:customers, :retrieve)
        .and_return(stripe_customer)

      # Mock price ID retrieval
      allow(Rails.application.credentials).to receive(:stripe).and_return({
        premium_monthly_price_id: 'price_monthly_test',
        premium_yearly_price_id: 'price_yearly_test'
      })
    end

    context 'with valid discount code' do
      it 'creates Stripe coupon and applies discount to checkout session' do
        # Mock coupon creation
        stripe_coupon = double('Stripe::Coupon', id: 'discount_welcome20_20pct')
        allow(@stripe_client_mock).to receive_message_chain(:coupons, :retrieve)
          .and_raise(Stripe::InvalidRequestError.new('Not found', 'coupon'))
        expect(@stripe_client_mock).to receive_message_chain(:coupons, :create)
          .with({
            id: 'discount_welcome20_20pct',
            percent_off: 20,
            duration: 'once',
            name: '20% off (WELCOME20)',
            metadata: {
              discount_code_id: discount_code.id,
              created_by: 'agentform_system'
            }
          })
          .and_return(stripe_coupon)

        # Mock checkout session creation
        stripe_session = double('Stripe::CheckoutSession', 
          id: 'cs_test123', 
          url: 'https://checkout.stripe.com/pay/cs_test123'
        )

        expect(@stripe_client_mock).to receive_message_chain(:checkout, :sessions, :create) do |params|
          # Verify discount metadata is included
          expect(params[:metadata][:discount_code]).to eq('WELCOME20')
          expect(params[:metadata][:discount_percentage]).to eq(20)
          expect(params[:metadata][:original_amount]).to eq(2900)
          expect(params[:metadata][:discount_amount]).to eq(580)
          expect(params[:metadata][:final_amount]).to eq(2320)
          
          # Verify discount is applied
          expect(params[:discounts]).to eq([{ coupon: 'discount_welcome20_20pct' }])
          
          stripe_session
        end

        result = service.create_subscription(
          billing_cycle: 'monthly',
          discount_code: 'WELCOME20',
          success_url: success_url,
          cancel_url: cancel_url
        )

        expect(result.success?).to be true
        expect(result.data[:checkout_url]).to eq('https://checkout.stripe.com/pay/cs_test123')
        expect(result.data[:discount_applied]).to be true
      end

      it 'reuses existing Stripe coupon if available' do
        # Mock existing coupon retrieval
        stripe_coupon = double('Stripe::Coupon', id: 'discount_welcome20_20pct')
        expect(@stripe_client_mock).to receive_message_chain(:coupons, :retrieve)
          .with('discount_welcome20_20pct')
          .and_return(stripe_coupon)

        # Should not create a new coupon (we'll verify this by not setting up the expectation)

        # Mock checkout session creation
        stripe_session = double('Stripe::CheckoutSession', 
          id: 'cs_test123', 
          url: 'https://checkout.stripe.com/pay/cs_test123'
        )
        allow(@stripe_client_mock).to receive_message_chain(:checkout, :sessions, :create)
          .and_return(stripe_session)

        result = service.create_subscription(
          billing_cycle: 'monthly',
          discount_code: 'WELCOME20',
          success_url: success_url,
          cancel_url: cancel_url
        )

        expect(result.success?).to be true
      end

      it 'handles yearly billing cycle with discount' do
        # Mock coupon creation
        stripe_coupon = double('Stripe::Coupon', id: 'discount_welcome20_20pct')
        allow(@stripe_client_mock).to receive_message_chain(:coupons, :retrieve)
          .and_raise(Stripe::InvalidRequestError.new('Not found', 'coupon'))
        allow(@stripe_client_mock).to receive_message_chain(:coupons, :create)
          .and_return(stripe_coupon)

        # Mock checkout session creation
        stripe_session = double('Stripe::CheckoutSession', 
          id: 'cs_test123', 
          url: 'https://checkout.stripe.com/pay/cs_test123'
        )

        expect(@stripe_client_mock).to receive_message_chain(:checkout, :sessions, :create) do |params|
          # Verify yearly pricing with discount
          expect(params[:metadata][:original_amount]).to eq(29000) # $290.00
          expect(params[:metadata][:discount_amount]).to eq(5800)  # 20% of $290.00
          expect(params[:metadata][:final_amount]).to eq(23200)    # $290.00 - $58.00
          
          stripe_session
        end

        result = service.create_subscription(
          billing_cycle: 'yearly',
          discount_code: 'WELCOME20',
          success_url: success_url,
          cancel_url: cancel_url
        )

        expect(result.success?).to be true
      end
    end

    context 'with invalid discount code' do
      it 'returns error for invalid discount code' do
        result = service.create_subscription(
          billing_cycle: 'monthly',
          discount_code: 'INVALID',
          success_url: success_url,
          cancel_url: cancel_url
        )

        expect(result.success?).to be false
        expect(result.error).to include('Invalid discount code')
      end

      it 'returns error for user who already used a discount' do
        user.update!(discount_code_used: true)

        result = service.create_subscription(
          billing_cycle: 'monthly',
          discount_code: 'WELCOME20',
          success_url: success_url,
          cancel_url: cancel_url
        )

        expect(result.success?).to be false
        expect(result.error).to include('already used')
      end

      it 'returns error for expired discount code' do
        discount_code.update!(expires_at: 1.day.ago)

        result = service.create_subscription(
          billing_cycle: 'monthly',
          discount_code: 'WELCOME20',
          success_url: success_url,
          cancel_url: cancel_url
        )

        expect(result.success?).to be false
        expect(result.error).to include('expired')
      end
    end

    context 'without discount code' do
      it 'creates subscription without discount metadata' do
        # Mock checkout session creation
        stripe_session = double('Stripe::CheckoutSession', 
          id: 'cs_test123', 
          url: 'https://checkout.stripe.com/pay/cs_test123'
        )

        expect(@stripe_client_mock).to receive_message_chain(:checkout, :sessions, :create) do |params|
          # Verify no discount metadata
          expect(params[:metadata]).not_to have_key(:discount_code)
          expect(params).not_to have_key(:discounts)
          
          stripe_session
        end

        result = service.create_subscription(
          billing_cycle: 'monthly',
          success_url: success_url,
          cancel_url: cancel_url
        )

        expect(result.success?).to be true
        expect(result.data[:discount_applied]).to be false
      end
    end

    context 'when Stripe coupon creation fails' do
      it 'continues without discount if coupon creation fails' do
        # Mock coupon creation failure
        allow(@stripe_client_mock).to receive_message_chain(:coupons, :retrieve)
          .and_raise(Stripe::InvalidRequestError.new('Not found', 'coupon'))
        allow(@stripe_client_mock).to receive_message_chain(:coupons, :create)
          .and_raise(Stripe::StripeError.new('Coupon creation failed'))

        # Mock checkout session creation
        stripe_session = double('Stripe::CheckoutSession', 
          id: 'cs_test123', 
          url: 'https://checkout.stripe.com/pay/cs_test123'
        )

        expect(@stripe_client_mock).to receive_message_chain(:checkout, :sessions, :create) do |params|
          # Should still include metadata but no discount coupon
          expect(params[:metadata][:discount_code]).to eq('WELCOME20')
          expect(params).not_to have_key(:discounts)
          
          stripe_session
        end

        result = service.create_subscription(
          billing_cycle: 'monthly',
          discount_code: 'WELCOME20',
          success_url: success_url,
          cancel_url: cancel_url
        )

        expect(result.success?).to be true
      end
    end
  end
end