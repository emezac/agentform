# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe "AI Credit Management" do
    let(:user) { create(:user, ai_credits_used: 5.0, monthly_ai_limit: 10.0) }

    describe "validations" do
      it "validates ai_credits_used is present and non-negative" do
        user = build(:user, ai_credits_used: nil)
        expect(user).not_to be_valid
        expect(user.errors[:ai_credits_used]).to include("can't be blank")

        user = build(:user, ai_credits_used: -1.0)
        expect(user).not_to be_valid
        expect(user.errors[:ai_credits_used]).to include("must be greater than or equal to 0")

        user = build(:user, ai_credits_used: 0.0)
        expect(user).to be_valid
      end

      it "validates monthly_ai_limit is present and positive" do
        user = build(:user, monthly_ai_limit: nil)
        expect(user).not_to be_valid
        expect(user.errors[:monthly_ai_limit]).to include("can't be blank")

        user = build(:user, monthly_ai_limit: 0.0)
        expect(user).not_to be_valid
        expect(user.errors[:monthly_ai_limit]).to include("must be greater than 0")

        user = build(:user, monthly_ai_limit: -1.0)
        expect(user).not_to be_valid
        expect(user.errors[:monthly_ai_limit]).to include("must be greater than 0")

        user = build(:user, monthly_ai_limit: 10.0)
        expect(user).to be_valid
      end
    end

    describe "#ai_credits_used_this_month" do
      it "returns the current ai_credits_used as a float" do
        expect(user.ai_credits_used_this_month).to eq(5.0)
      end

      it "returns 0.0 when ai_credits_used is nil" do
        user.update_column(:ai_credits_used, nil)
        expect(user.ai_credits_used_this_month).to eq(0.0)
      end

      it "converts decimal values to float" do
        user.update!(ai_credits_used: BigDecimal('7.5'))
        expect(user.ai_credits_used_this_month).to eq(7.5)
        expect(user.ai_credits_used_this_month).to be_a(Float)
      end
    end

    describe "#ai_credits_remaining" do
      it "calculates remaining credits correctly" do
        expect(user.ai_credits_remaining).to eq(5.0) # 10.0 - 5.0
      end

      it "returns 0.0 when credits are exhausted" do
        user.update!(ai_credits_used: 10.0)
        expect(user.ai_credits_remaining).to eq(0.0)
      end

      it "returns 0.0 when over limit (never negative)" do
        user.update!(ai_credits_used: 15.0)
        expect(user.ai_credits_remaining).to eq(0.0)
      end

      it "handles nil values gracefully" do
        user.update_columns(ai_credits_used: nil, monthly_ai_limit: nil)
        expect(user.ai_credits_remaining).to eq(0.0)
      end

      it "handles decimal precision correctly" do
        user.update!(ai_credits_used: 3.25, monthly_ai_limit: 10.75)
        expect(user.ai_credits_remaining).to eq(7.5)
      end
    end

    describe "#consume_ai_credit" do
      context "when user can use AI features" do
        before do
          allow(user).to receive(:can_use_ai_features?).and_return(true)
        end

        it "consumes credits and returns true when successful" do
          expect(user.consume_ai_credit(2.0)).to be true
          expect(user.reload.ai_credits_used).to eq(7.0)
        end

        it "uses default cost of 1.0 when no cost specified" do
          expect(user.consume_ai_credit).to be true
          expect(user.reload.ai_credits_used).to eq(6.0)
        end

        it "converts cost to float" do
          expect(user.consume_ai_credit(BigDecimal('1.5'))).to be true
          expect(user.reload.ai_credits_used).to eq(6.5)
        end

        it "returns false when cost is zero or negative" do
          expect(user.consume_ai_credit(0)).to be false
          expect(user.consume_ai_credit(-1.0)).to be false
          expect(user.reload.ai_credits_used).to eq(5.0) # No change
        end

        it "returns false when user doesn't have enough credits" do
          expect(user.consume_ai_credit(6.0)).to be false # Only 5.0 remaining
          expect(user.reload.ai_credits_used).to eq(5.0) # No change
        end

        it "allows consuming exactly the remaining credits" do
          expect(user.consume_ai_credit(5.0)).to be true
          expect(user.reload.ai_credits_used).to eq(10.0)
          expect(user.ai_credits_remaining).to eq(0.0)
        end
      end

      context "when user cannot use AI features" do
        before do
          allow(user).to receive(:can_use_ai_features?).and_return(false)
        end

        it "returns false and doesn't consume credits" do
          expect(user.consume_ai_credit(1.0)).to be false
          expect(user.reload.ai_credits_used).to eq(5.0) # No change
        end
      end
    end

    describe "#can_consume_ai_credit?" do
      context "when user can use AI features" do
        before do
          allow(user).to receive(:can_use_ai_features?).and_return(true)
        end

        it "returns true when user has enough credits" do
          expect(user.can_consume_ai_credit?(3.0)).to be true
          expect(user.can_consume_ai_credit?(5.0)).to be true # Exactly remaining
        end

        it "returns false when user doesn't have enough credits" do
          expect(user.can_consume_ai_credit?(6.0)).to be false
        end

        it "returns false for zero or negative costs" do
          expect(user.can_consume_ai_credit?(0)).to be false
          expect(user.can_consume_ai_credit?(-1.0)).to be false
        end

        it "uses default cost of 1.0 when no cost specified" do
          expect(user.can_consume_ai_credit?).to be true
        end
      end

      context "when user cannot use AI features" do
        before do
          allow(user).to receive(:can_use_ai_features?).and_return(false)
        end

        it "returns false regardless of credit balance" do
          expect(user.can_consume_ai_credit?(1.0)).to be false
        end
      end
    end

    describe "database constraints and indexes" do
      it "has proper decimal precision for ai_credits_used" do
        user.update!(ai_credits_used: 123.4567)
        expect(user.reload.ai_credits_used).to eq(123.4567)
      end

      it "has proper decimal precision for monthly_ai_limit" do
        user.update!(monthly_ai_limit: 999.9999)
        expect(user.reload.monthly_ai_limit).to eq(999.9999)
      end

      it "has indexes for efficient queries" do
        # These indexes should exist based on the migration
        indexes = ActiveRecord::Base.connection.indexes('users')
        
        ai_credits_used_index = indexes.find { |i| i.columns == ['ai_credits_used'] }
        expect(ai_credits_used_index).to be_present

        monthly_ai_limit_index = indexes.find { |i| i.columns == ['monthly_ai_limit'] }
        expect(monthly_ai_limit_index).to be_present

        combined_index = indexes.find { |i| i.columns == ['ai_credits_used', 'monthly_ai_limit'] }
        expect(combined_index).to be_present
        expect(combined_index.name).to eq('index_users_on_ai_credits')
      end
    end

    describe "integration with existing methods" do
      it "works with can_use_ai_features?" do
        premium_user = create(:user, subscription_tier: 'premium', ai_credits_used: 5.0, monthly_ai_limit: 10.0)
        expect(premium_user.can_use_ai_features?).to be true
        expect(premium_user.can_consume_ai_credit?(3.0)).to be true

        basic_user = create(:user, subscription_tier: 'freemium', ai_credits_used: 5.0, monthly_ai_limit: 10.0)
        expect(basic_user.can_use_ai_features?).to be false
        expect(basic_user.can_consume_ai_credit?(3.0)).to be false
      end
    end
  end
end