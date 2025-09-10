require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'trial end date functionality' do
    let(:user) { create(:user, email: 'emezac@gmail.com') }

    describe 'setting trial_ends_at for existing user' do
      context 'when user is in trialing status' do
        before do
          user.update!(
            subscription_status: 'trialing',
            created_at: 30.days.ago,
            trial_ends_at: nil
          )
        end

        it 'sets trial_ends_at based on created_at date' do
          # Manually set trial end date like our rake task does
          new_trial_end = TrialConfig.trial_end_date(user.created_at)
          user.update!(trial_ends_at: new_trial_end)

          expect(user.trial_ends_at).to eq(user.created_at + TrialConfig.trial_period_days.days)
        end

        it 'calculates trial days remaining correctly for expired trial' do
          # Set trial end date based on created_at (30 days ago + 14 days = 16 days ago)
          user.update!(trial_ends_at: TrialConfig.trial_end_date(user.created_at))

          expect(user.trial_days_remaining).to eq(0)
          expect(user.trial_expired?).to be true
          expect(user.trial_expires_soon?).to be false
          expect(user.trial_expires_today?).to be false
          expect(user.trial_status_message).to eq("Your trial has expired")
        end
      end

      context 'when user has active trial' do
        before do
          user.update!(
            subscription_status: 'trialing',
            created_at: 5.days.ago,
            trial_ends_at: TrialConfig.trial_end_date(5.days.ago)
          )
        end

        it 'calculates trial days remaining correctly for active trial' do
          expected_days = (user.trial_ends_at - Time.current) / 1.day
          expected_days = expected_days.ceil

          expect(user.trial_days_remaining).to eq(expected_days)
          expect(user.trial_expired?).to be false
          expect(user.trial_status_message).to include("days remaining")
        end
      end

      context 'when trial expires soon' do
        before do
          user.update!(
            subscription_status: 'trialing',
            created_at: 12.days.ago,
            trial_ends_at: TrialConfig.trial_end_date(12.days.ago)
          )
        end

        it 'identifies trials expiring soon' do
          expect(user.trial_days_remaining).to be <= 7
          expect(user.trial_expires_soon?).to be true
          expect(user.trial_expired?).to be false
        end
      end
    end

    describe 'TrialConfig integration' do
      it 'uses configured trial period days' do
        expect(TrialConfig.trial_period_days).to eq(14)
        expect(TrialConfig.trial_enabled?).to be true
      end

      it 'calculates trial end date correctly' do
        start_date = 10.days.ago
        expected_end = start_date + 14.days

        expect(TrialConfig.trial_end_date(start_date)).to eq(expected_end)
      end
    end
  end
end