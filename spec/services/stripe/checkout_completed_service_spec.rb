require 'rails_helper'
require 'ostruct'

RSpec.describe Stripe::CheckoutCompletedService, type: :service do
  let(:user) { create(:user, subscription_tier: 'freemium', confirmed_at: nil) }
  let!(:discount_code) { create(:discount_code, code: 'WELCOME20', discount_percentage: 20, active: true) }

  describe '#call' do
    context 'with discount code applied' do
      let(:session_data) do
        OpenStruct.new({
          id: 'cs_test_123',
          customer: 'cus_test_123',
          subscription: 'sub_test_123',
          metadata: OpenStruct.new({
            user_id: user.id,
            discount_code: 'WELCOME20',
            discount_percentage: '20',
            original_amount: '2900',
            discount_amount: '580',
            final_amount: '2320'
          })
        })
      end

      let(:event) { double('StripeEvent', data: double('EventData', object: session_data)) }
      let(:service) { described_class.new(event) }

      it 'records discount usage and upgrades user' do
        expect {
          service.call
        }.to change { DiscountCodeUsage.count }.by(1)
          .and change { user.reload.subscription_tier }.from('freemium').to('premium')
          .and change { user.reload.discount_code_used }.from(false).to(true)
          .and change { discount_code.reload.current_usage_count }.by(1)

        # Verify user subscription is updated
        expect(user.reload.subscription_tier).to eq('premium')

        # Verify discount usage record
        usage = DiscountCodeUsage.last
        expect(usage.user).to eq(user)
        expect(usage.discount_code).to eq(discount_code)
        expect(usage.subscription_id).to eq('sub_test_123')
        expect(usage.original_amount).to eq(2900)
        expect(usage.discount_amount).to eq(580)
        expect(usage.final_amount).to eq(2320)
      end

      it 'handles missing discount code gracefully' do
        # Create event with non-existent discount code
        session_data[:metadata][:discount_code] = 'NONEXISTENT'
        
        initial_usage_count = DiscountCodeUsage.count
        initial_discount_used = user.discount_code_used
        
        service.call
        
        expect(user.reload.subscription_tier).to eq('premium')
        expect(DiscountCodeUsage.count).to eq(initial_usage_count)
        expect(user.reload.discount_code_used).to eq(initial_discount_used)
      end

      it 'handles discount usage recording errors gracefully' do
        # Make user ineligible for discount (already used one)
        user.update!(discount_code_used: true)
        
        initial_usage_count = DiscountCodeUsage.count
        
        service.call
        
        expect(user.reload.subscription_tier).to eq('premium')
        expect(DiscountCodeUsage.count).to eq(initial_usage_count)
      end

      it 'deactivates discount code when usage limit is reached' do
        # Set discount code to have only 1 use remaining
        discount_code.update!(max_usage_count: 1, current_usage_count: 0)

        expect {
          service.call
        }.to change { discount_code.reload.active }.from(true).to(false)
          .and change { discount_code.reload.current_usage_count }.from(0).to(1)
      end
    end

    context 'without discount code' do
      let(:session_data) do
        OpenStruct.new({
          id: 'cs_test_123',
          customer: 'cus_test_123',
          subscription: 'sub_test_123',
          metadata: OpenStruct.new({
            user_id: user.id
            # No discount code metadata
          })
        })
      end

      let(:event) { double('StripeEvent', data: double('EventData', object: session_data)) }
      let(:service) { described_class.new(event) }

      it 'upgrades user without processing discount' do
        initial_usage_count = DiscountCodeUsage.count
        initial_discount_used = user.discount_code_used
        
        service.call
        
        expect(user.reload.subscription_tier).to eq('premium')
        expect(DiscountCodeUsage.count).to eq(initial_usage_count)
        expect(user.reload.discount_code_used).to eq(initial_discount_used)
        expect(user.reload.stripe_customer_id).to eq('cus_test_123')
        expect(user.reload.subscription_status).to eq('active')
      end
    end

    context 'with invalid user ID' do
      let(:session_data) do
        OpenStruct.new({
          id: 'cs_test_123',
          customer: 'cus_test_123',
          subscription: 'sub_test_123',
          metadata: OpenStruct.new({
            user_id: 'invalid_user_id',
            discount_code: 'WELCOME20'
          })
        })
      end

      let(:event) { double('StripeEvent', data: double('EventData', object: session_data)) }
      let(:service) { described_class.new(event) }

      it 'logs error and returns early' do
        expect(Rails.logger).to receive(:error).with(/User not found/)

        initial_usage_count = DiscountCodeUsage.count
        initial_subscription_tier = user.subscription_tier
        
        service.call
        
        expect(DiscountCodeUsage.count).to eq(initial_usage_count)
        expect(user.reload.subscription_tier).to eq(initial_subscription_tier)
      end
    end

    context 'with missing user ID' do
      let(:session_data) do
        OpenStruct.new({
          id: 'cs_test_123',
          customer: 'cus_test_123',
          subscription: 'sub_test_123',
          metadata: OpenStruct.new({
            # No user_id
            discount_code: 'WELCOME20'
          })
        })
      end

      let(:event) { double('StripeEvent', data: double('EventData', object: session_data)) }
      let(:service) { described_class.new(event) }

      it 'logs error and returns early' do
        expect(Rails.logger).to receive(:error).with(/User not found/)

        initial_usage_count = DiscountCodeUsage.count
        
        service.call
        
        expect(DiscountCodeUsage.count).to eq(initial_usage_count)
      end
    end
  end
end