require 'rails_helper'

RSpec.describe DiscountCodeUsage, type: :model do
  let(:user) { create(:user) }
  let(:creator) { create(:user) }
  let(:discount_code) { create(:discount_code, created_by: creator) }
  
  describe 'associations' do
    it { should belong_to(:discount_code) }
    it { should belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:discount_code_usage, discount_code: discount_code, user: user) }

    it { should validate_presence_of(:user_id) }
    it { should validate_uniqueness_of(:user_id).ignoring_case_sensitivity }
    it { should validate_presence_of(:discount_code_id) }
    it { should validate_presence_of(:original_amount) }
    it { should validate_numericality_of(:original_amount).is_greater_than(0) }
    it { should validate_presence_of(:discount_amount) }
    it { should validate_numericality_of(:discount_amount).is_greater_than(0) }
    it { should validate_presence_of(:final_amount) }
    it { should validate_numericality_of(:final_amount).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:used_at) }

    describe 'unique user constraint' do
      let!(:existing_usage) { create(:discount_code_usage, user: user) }
      
      it 'prevents the same user from using multiple discount codes' do
        new_usage = build(:discount_code_usage, user: user, discount_code: discount_code)
        expect(new_usage).not_to be_valid
        expect(new_usage.errors[:user_id]).to include('has already been taken')
      end
    end

    describe 'custom validations' do
      describe '#final_amount_calculation_is_correct' do
        context 'when final_amount equals original_amount minus discount_amount' do
          let(:usage) do
            build(:discount_code_usage, 
                  discount_code: discount_code, 
                  user: user,
                  original_amount: 5000,
                  discount_amount: 1000,
                  final_amount: 4000)
          end

          it 'is valid' do
            expect(usage).to be_valid
          end
        end

        context 'when final_amount does not equal original_amount minus discount_amount' do
          let(:usage) do
            build(:discount_code_usage, 
                  discount_code: discount_code, 
                  user: user,
                  original_amount: 5000,
                  discount_amount: 1000,
                  final_amount: 3500)
          end

          it 'is invalid' do
            expect(usage).not_to be_valid
            expect(usage.errors[:final_amount]).to include('must equal original amount minus discount amount (4000)')
          end
        end
      end

      describe '#discount_amount_not_greater_than_original' do
        context 'when discount_amount is less than original_amount' do
          let(:usage) do
            build(:discount_code_usage, 
                  discount_code: discount_code, 
                  user: user,
                  original_amount: 5000,
                  discount_amount: 1000,
                  final_amount: 4000)
          end

          it 'is valid' do
            expect(usage).to be_valid
          end
        end

        context 'when discount_amount equals original_amount' do
          let(:usage) do
            build(:discount_code_usage, 
                  discount_code: discount_code, 
                  user: user,
                  original_amount: 5000,
                  discount_amount: 5000,
                  final_amount: 0)
          end

          it 'is valid' do
            expect(usage).to be_valid
          end
        end

        context 'when discount_amount is greater than original_amount' do
          let(:usage) do
            build(:discount_code_usage, 
                  discount_code: discount_code, 
                  user: user,
                  original_amount: 5000,
                  discount_amount: 6000,
                  final_amount: -1000)
          end

          it 'is invalid' do
            expect(usage).not_to be_valid
            expect(usage.errors[:discount_amount]).to include('cannot be greater than original amount')
          end
        end
      end
    end
  end

  describe 'scopes' do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:code1) { create(:discount_code, created_by: creator) }
    let(:code2) { create(:discount_code, created_by: creator) }
    
    let!(:usage1) { create(:discount_code_usage, user: user1, discount_code: code1, used_at: 2.days.ago) }
    let!(:usage2) { create(:discount_code_usage, user: user2, discount_code: code2, used_at: 1.day.ago) }

    describe '.recent' do
      it 'orders by used_at descending' do
        expect(DiscountCodeUsage.recent).to eq([usage2, usage1])
      end
    end

    describe '.by_discount_code' do
      it 'filters by discount code' do
        expect(DiscountCodeUsage.by_discount_code(code1)).to include(usage1)
        expect(DiscountCodeUsage.by_discount_code(code1)).not_to include(usage2)
      end
    end

    describe '.by_user' do
      it 'filters by user' do
        expect(DiscountCodeUsage.by_user(user1)).to include(usage1)
        expect(DiscountCodeUsage.by_user(user1)).not_to include(usage2)
      end
    end
  end

  describe '#savings_percentage' do
    context 'when original_amount is zero' do
      let(:usage) do
        build(:discount_code_usage, 
              discount_code: discount_code, 
              user: user,
              original_amount: 0,
              discount_amount: 0,
              final_amount: 0)
      end

      it 'returns 0' do
        expect(usage.savings_percentage).to eq(0)
      end
    end

    context 'when discount_amount is 1000 and original_amount is 5000' do
      let(:usage) do
        build(:discount_code_usage, 
              discount_code: discount_code, 
              user: user,
              original_amount: 5000,
              discount_amount: 1000,
              final_amount: 4000)
      end

      it 'returns 20.0' do
        expect(usage.savings_percentage).to eq(20.0)
      end
    end

    context 'when discount_amount is 1500 and original_amount is 5000' do
      let(:usage) do
        build(:discount_code_usage, 
              discount_code: discount_code, 
              user: user,
              original_amount: 5000,
              discount_amount: 1500,
              final_amount: 3500)
      end

      it 'returns 30.0' do
        expect(usage.savings_percentage).to eq(30.0)
      end
    end
  end

  describe 'formatted amount methods' do
    let(:usage) do
      build(:discount_code_usage, 
            discount_code: discount_code, 
            user: user,
            original_amount: 5000,
            discount_amount: 1000,
            final_amount: 4000)
    end

    describe '#formatted_original_amount' do
      it 'formats the original amount as currency' do
        expect(usage.formatted_original_amount).to eq('$50.00')
      end
    end

    describe '#formatted_discount_amount' do
      it 'formats the discount amount as currency' do
        expect(usage.formatted_discount_amount).to eq('$10.00')
      end
    end

    describe '#formatted_final_amount' do
      it 'formats the final amount as currency' do
        expect(usage.formatted_final_amount).to eq('$40.00')
      end
    end

    context 'with zero amounts' do
      let(:zero_usage) do
        build(:discount_code_usage, 
              discount_code: discount_code, 
              user: user,
              original_amount: 0,
              discount_amount: 0,
              final_amount: 0)
      end

      it 'formats zero amounts correctly' do
        expect(zero_usage.formatted_original_amount).to eq('$0.00')
        expect(zero_usage.formatted_discount_amount).to eq('$0.00')
        expect(zero_usage.formatted_final_amount).to eq('$0.00')
      end
    end

    context 'with large amounts' do
      let(:large_usage) do
        build(:discount_code_usage, 
              discount_code: discount_code, 
              user: user,
              original_amount: 999999,
              discount_amount: 100000,
              final_amount: 899999)
      end

      it 'formats large amounts correctly' do
        expect(large_usage.formatted_original_amount).to eq('$9,999.99')
        expect(large_usage.formatted_discount_amount).to eq('$1,000.00')
        expect(large_usage.formatted_final_amount).to eq('$8,999.99')
      end
    end
  end

  describe 'edge cases and validations' do
    describe 'concurrent usage prevention' do
      it 'prevents duplicate usage records for same user' do
        create(:discount_code_usage, user: user, discount_code: discount_code)
        
        duplicate_usage = build(:discount_code_usage, user: user, discount_code: discount_code)
        expect(duplicate_usage).not_to be_valid
        expect(duplicate_usage.errors[:user_id]).to include('has already been taken')
      end
    end

    describe 'amount validation edge cases' do
      it 'allows zero final amount (100% discount)' do
        usage = build(:discount_code_usage, 
                      discount_code: discount_code, 
                      user: user,
                      original_amount: 1000,
                      discount_amount: 1000,
                      final_amount: 0)
        expect(usage).to be_valid
      end

      it 'rejects negative amounts' do
        usage = build(:discount_code_usage, 
                      discount_code: discount_code, 
                      user: user,
                      original_amount: -1000,
                      discount_amount: 100,
                      final_amount: -900)
        expect(usage).not_to be_valid
        expect(usage.errors[:original_amount]).to include('must be greater than 0')
      end
    end

    describe 'timestamp handling' do
      it 'sets used_at to current time by default' do
        freeze_time do
          usage = create(:discount_code_usage, discount_code: discount_code, user: user)
          expect(usage.used_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'allows custom used_at timestamp' do
        custom_time = 1.day.ago
        usage = create(:discount_code_usage, 
                       discount_code: discount_code, 
                       user: user, 
                       used_at: custom_time)
        expect(usage.used_at).to be_within(1.second).of(custom_time)
      end
    end
  end

  describe 'database integrity' do
    it 'cascades deletion when discount code is deleted' do
      usage = create(:discount_code_usage, discount_code: discount_code, user: user)
      
      expect {
        discount_code.destroy
      }.to change(DiscountCodeUsage, :count).by(-1)
    end

    it 'cascades deletion when user is deleted' do
      usage = create(:discount_code_usage, discount_code: discount_code, user: user)
      
      expect {
        user.destroy
      }.to change(DiscountCodeUsage, :count).by(-1)
    end
  end
end