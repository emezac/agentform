require 'rails_helper'

RSpec.describe User, type: :model do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, role: 'admin') }
  
  describe 'discount code associations' do
    it { should have_many(:created_discount_codes).class_name('DiscountCode').with_foreign_key('created_by_id').dependent(:destroy) }
    it { should have_one(:discount_code_usage).dependent(:destroy) }
    it { should have_one(:used_discount_code).through(:discount_code_usage).source(:discount_code) }
  end

  describe 'discount code eligibility methods' do
    describe '#eligible_for_discount?' do
      context 'when user has not used a discount code and is not suspended' do
        it 'returns true' do
          expect(user.eligible_for_discount?).to be true
        end
      end

      context 'when user has used a discount code' do
        before { user.update!(discount_code_used: true) }

        it 'returns false' do
          expect(user.eligible_for_discount?).to be false
        end
      end

      context 'when user is suspended' do
        before { user.suspend!('Violation of terms') }

        it 'returns false' do
          expect(user.eligible_for_discount?).to be false
        end
      end

      context 'when user has used a discount code and is suspended' do
        before do
          user.update!(discount_code_used: true)
          user.suspend!('Violation of terms')
        end

        it 'returns false' do
          expect(user.eligible_for_discount?).to be false
        end
      end
    end

    describe '#can_use_discount_code?' do
      it 'returns the same as eligible_for_discount?' do
        expect(user.can_use_discount_code?).to eq(user.eligible_for_discount?)
      end
    end

    describe '#discount_code_used?' do
      context 'when discount_code_used field is true' do
        before { user.update!(discount_code_used: true) }

        it 'returns true' do
          expect(user.discount_code_used?).to be true
        end
      end

      context 'when user has a discount_code_usage record' do
        let(:discount_code) { create(:discount_code, created_by: admin_user) }
        
        before do
          create(:discount_code_usage, user: user, discount_code: discount_code)
        end

        it 'returns true' do
          expect(user.discount_code_used?).to be true
        end
      end

      context 'when discount_code_used is false and no usage record exists' do
        it 'returns false' do
          expect(user.discount_code_used?).to be false
        end
      end

      context 'when discount_code_used is false and no usage record exists' do
        before { user.update!(discount_code_used: false) }

        it 'returns false' do
          expect(user.discount_code_used?).to be false
        end
      end
    end

    describe '#mark_discount_code_as_used!' do
      it 'sets discount_code_used to true' do
        expect { user.mark_discount_code_as_used! }
          .to change { user.reload.discount_code_used }.from(false).to(true)
      end
    end
  end

  describe 'user suspension methods' do
    describe '#suspended?' do
      context 'when suspended_at is nil' do
        it 'returns false' do
          expect(user.suspended?).to be false
        end
      end

      context 'when suspended_at is present' do
        before { user.update!(suspended_at: Time.current) }

        it 'returns true' do
          expect(user.suspended?).to be true
        end
      end
    end

    describe '#active_user?' do
      it 'returns the opposite of suspended?' do
        expect(user.active_user?).to eq(!user.suspended?)
      end
    end

    describe '#suspend!' do
      let(:reason) { 'Violation of terms of service' }

      it 'sets suspended_at to current time' do
        freeze_time do
          user.suspend!(reason)
          expect(user.suspended_at).to eq(Time.current)
        end
      end

      it 'sets suspended_reason' do
        user.suspend!(reason)
        expect(user.suspended_reason).to eq(reason)
      end

      it 'persists the changes to the database' do
        user.suspend!(reason)
        user.reload
        expect(user.suspended?).to be true
        expect(user.suspended_reason).to eq(reason)
      end
    end

    describe '#reactivate!' do
      before do
        user.suspend!('Test suspension')
      end

      it 'clears suspended_at' do
        user.reactivate!
        expect(user.suspended_at).to be_nil
      end

      it 'clears suspended_reason' do
        user.reactivate!
        expect(user.suspended_reason).to be_nil
      end

      it 'persists the changes to the database' do
        user.reactivate!
        user.reload
        expect(user.suspended?).to be false
        expect(user.suspended_reason).to be_nil
      end
    end

    describe '#suspension_duration' do
      context 'when user is not suspended' do
        it 'returns nil' do
          expect(user.suspension_duration).to be_nil
        end
      end

      context 'when user is suspended' do
        before do
          travel_to 2.days.ago do
            user.suspend!('Test suspension')
          end
        end

        it 'returns the duration since suspension' do
          expect(user.suspension_duration).to be_within(1.second).of(2.days)
        end
      end
    end

    describe '#suspension_duration_in_days' do
      context 'when user is not suspended' do
        it 'returns nil' do
          expect(user.suspension_duration_in_days).to be_nil
        end
      end

      context 'when user was suspended 2 days ago' do
        before do
          travel_to 2.days.ago do
            user.suspend!('Test suspension')
          end
        end

        it 'returns 2' do
          expect(user.suspension_duration_in_days).to eq(2)
        end
      end

      context 'when user was suspended 2.7 days ago' do
        before do
          travel_to 2.7.days.ago do
            user.suspend!('Test suspension')
          end
        end

        it 'returns 3 (rounded)' do
          expect(user.suspension_duration_in_days).to eq(3)
        end
      end
    end
  end

  describe 'premium user discount eligibility' do
    let(:premium_user) { create(:user, subscription_tier: 'premium') }

    describe '#eligible_for_discount?' do
      it 'returns false for premium users' do
        expect(premium_user.eligible_for_discount?).to be false
      end
    end

    context 'when premium user has not used discount and is not suspended' do
      it 'is still ineligible due to premium status' do
        expect(premium_user.discount_code_used?).to be false
        expect(premium_user.suspended?).to be false
        expect(premium_user.eligible_for_discount?).to be false
      end
    end
  end

  describe 'edge cases and validations' do
    describe '#mark_discount_code_as_used!' do
      it 'is idempotent' do
        user.mark_discount_code_as_used!
        expect(user.discount_code_used).to be true
        
        # Calling again should not raise error
        expect { user.mark_discount_code_as_used! }.not_to raise_error
        expect(user.reload.discount_code_used).to be true
      end

      it 'persists across reloads' do
        user.mark_discount_code_as_used!
        reloaded_user = User.find(user.id)
        expect(reloaded_user.discount_code_used?).to be true
      end
    end

    describe 'suspension edge cases' do
      it 'handles suspension with empty reason' do
        user.suspend!('')
        expect(user.suspended?).to be true
        expect(user.suspended_reason).to eq('')
      end

      it 'handles suspension with nil reason' do
        user.suspend!(nil)
        expect(user.suspended?).to be true
        expect(user.suspended_reason).to be_nil
      end

      it 'handles multiple suspensions' do
        first_time = 2.days.ago
        second_time = 1.day.ago
        
        travel_to first_time do
          user.suspend!('First violation')
        end
        
        travel_to second_time do
          user.suspend!('Second violation')
        end
        
        expect(user.suspended_at).to be_within(1.second).of(second_time)
        expect(user.suspended_reason).to eq('Second violation')
      end
    end

    describe 'reactivation edge cases' do
      it 'handles reactivation of non-suspended user' do
        expect(user.suspended?).to be false
        
        expect { user.reactivate! }.not_to raise_error
        expect(user.suspended?).to be false
      end

      it 'clears all suspension data' do
        user.suspend!('Test reason')
        expect(user.suspended_at).to be_present
        expect(user.suspended_reason).to be_present
        
        user.reactivate!
        expect(user.suspended_at).to be_nil
        expect(user.suspended_reason).to be_nil
      end
    end

    describe 'suspension duration calculations' do
      context 'with fractional days' do
        before do
          travel_to 36.hours.ago do
            user.suspend!('Test suspension')
          end
        end

        it 'calculates duration correctly' do
          expect(user.suspension_duration).to be_within(1.minute).of(36.hours)
          expect(user.suspension_duration_in_days).to eq(2) # 1.5 days rounds to 2
        end
      end

      context 'with very short suspension' do
        before do
          travel_to 30.minutes.ago do
            user.suspend!('Brief suspension')
          end
        end

        it 'handles short durations' do
          expect(user.suspension_duration).to be_within(1.minute).of(30.minutes)
          expect(user.suspension_duration_in_days).to eq(0)
        end
      end
    end
  end

  describe 'integration scenarios' do
    let(:discount_code) { create(:discount_code, created_by: admin_user) }

    describe 'user uses discount code' do
      it 'becomes ineligible for future discount codes' do
        expect(user.eligible_for_discount?).to be true
        
        create(:discount_code_usage, user: user, discount_code: discount_code)
        
        expect(user.reload.eligible_for_discount?).to be false
      end

      it 'tracks usage through both flag and association' do
        expect(user.discount_code_used?).to be false
        
        create(:discount_code_usage, user: user, discount_code: discount_code)
        user.mark_discount_code_as_used!
        
        expect(user.discount_code_used?).to be true
        expect(user.used_discount_code).to eq(discount_code)
      end
    end

    describe 'user gets suspended' do
      it 'becomes ineligible for discount codes' do
        expect(user.eligible_for_discount?).to be true
        
        user.suspend!('Policy violation')
        
        expect(user.eligible_for_discount?).to be false
      end

      it 'can be reactivated and regain eligibility' do
        user.suspend!('Policy violation')
        expect(user.eligible_for_discount?).to be false
        
        user.reactivate!
        expect(user.eligible_for_discount?).to be true
      end

      it 'remains ineligible if discount was used before suspension' do
        user.mark_discount_code_as_used!
        user.suspend!('Policy violation')
        
        user.reactivate!
        expect(user.eligible_for_discount?).to be false
      end
    end

    describe 'complex eligibility scenarios' do
      it 'handles user with multiple ineligibility factors' do
        premium_user = create(:user, subscription_tier: 'premium')
        premium_user.mark_discount_code_as_used!
        premium_user.suspend!('Multiple violations')
        
        expect(premium_user.eligible_for_discount?).to be false
        expect(premium_user.discount_code_used?).to be true
        expect(premium_user.suspended?).to be true
      end

      it 'handles user transitioning between subscription tiers' do
        # Start as freemium user
        expect(user.eligible_for_discount?).to be true
        
        # Upgrade to premium
        user.update!(subscription_tier: 'premium')
        expect(user.reload.eligible_for_discount?).to be false
        
        # Downgrade back to freemium
        user.update!(subscription_tier: 'freemium')
        expect(user.reload.eligible_for_discount?).to be true
      end
    end
  end

  describe 'performance considerations' do
    it 'efficiently checks eligibility without N+1 queries' do
      # Create users with various states
      users = create_list(:user, 10)
      users.each_with_index do |u, i|
        u.mark_discount_code_as_used! if i.even?
        u.suspend!('Test') if i % 3 == 0
      end
      
      expect {
        User.all.map(&:eligible_for_discount?)
      }.to make_database_queries(count: 1..3) # Should be efficient
    end
  end
end