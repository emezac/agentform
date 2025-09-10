require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'Premium features' do
    let(:freemium_user) { create(:user, subscription_tier: 'freemium') }
    let(:premium_user) { create(:user, subscription_tier: 'premium') }
    let(:admin_user) { create(:user, role: 'admin') }

    describe '#premium?' do
      it 'returns false for freemium users' do
        expect(freemium_user.premium?).to be false
      end

      it 'returns true for premium users' do
        expect(premium_user.premium?).to be true
      end

      it 'returns true for admin users regardless of subscription tier' do
        admin_user.update!(subscription_tier: 'freemium')
        expect(admin_user.premium?).to be true
      end
    end

    describe '#can_accept_payments?' do
      context 'freemium user' do
        it 'returns false even with stripe configured' do
          freemium_user.update!(
            stripe_enabled: true,
            stripe_publishable_key: 'pk_test_123',
            stripe_secret_key: 'sk_test_123'
          )
          expect(freemium_user.can_accept_payments?).to be false
        end
      end

      context 'premium user' do
        it 'returns false without stripe configured' do
          expect(premium_user.can_accept_payments?).to be false
        end

        it 'returns true with stripe configured' do
          premium_user.update!(
            stripe_enabled: true,
            stripe_publishable_key: 'pk_test_123',
            stripe_secret_key: 'sk_test_123'
          )
          expect(premium_user.can_accept_payments?).to be true
        end
      end

      context 'admin user' do
        it 'returns true with stripe configured even if freemium tier' do
          admin_user.update!(
            subscription_tier: 'freemium',
            stripe_enabled: true,
            stripe_publishable_key: 'pk_test_123',
            stripe_secret_key: 'sk_test_123'
          )
          expect(admin_user.can_accept_payments?).to be true
        end
      end
    end

    describe '#stripe_configured?' do
      it 'returns false without stripe keys' do
        expect(freemium_user.stripe_configured?).to be false
      end

      it 'returns false with only publishable key' do
        freemium_user.update!(
          stripe_enabled: true,
          stripe_publishable_key: 'pk_test_123'
        )
        expect(freemium_user.stripe_configured?).to be false
      end

      it 'returns true with both keys' do
        freemium_user.update!(
          stripe_enabled: true,
          stripe_publishable_key: 'pk_test_123',
          stripe_secret_key: 'sk_test_123'
        )
        expect(freemium_user.stripe_configured?).to be true
      end
    end
  end
end