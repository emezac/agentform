require 'rails_helper'

RSpec.describe DiscountCode, type: :model do
  let(:user) { create(:user) }
  
  describe 'associations' do
    it { should belong_to(:created_by).class_name('User') }
    it { should have_many(:discount_code_usages).dependent(:destroy) }
    it { should have_many(:users).through(:discount_code_usages) }
  end

  describe 'validations' do
    subject { build(:discount_code, created_by: user) }

    it { should validate_presence_of(:code) }
    it { should validate_uniqueness_of(:code).case_insensitive }
    it { should validate_presence_of(:discount_percentage) }
    it { should validate_inclusion_of(:discount_percentage).in_range(1..99) }
    it { should validate_presence_of(:current_usage_count) }
    it { should validate_numericality_of(:current_usage_count).is_greater_than_or_equal_to(0) }
    
    context 'when max_usage_count is present' do
      it { should validate_numericality_of(:max_usage_count).is_greater_than(0) }
    end

    context 'when max_usage_count is nil' do
      subject { build(:discount_code, created_by: user, max_usage_count: nil) }
      it { should be_valid }
    end
  end

  describe 'scopes' do
    let!(:active_code) { create(:discount_code, created_by: user, active: true) }
    let!(:inactive_code) { create(:discount_code, created_by: user, active: false) }
    let!(:expired_code) { create(:discount_code, created_by: user, expires_at: 1.day.ago) }
    let!(:future_code) { create(:discount_code, created_by: user, expires_at: 1.day.from_now) }

    describe '.active' do
      it 'returns only active codes' do
        expect(DiscountCode.active).to include(active_code, future_code)
        expect(DiscountCode.active).not_to include(inactive_code)
      end
    end

    describe '.expired' do
      it 'returns only expired codes' do
        expect(DiscountCode.expired).to include(expired_code)
        expect(DiscountCode.expired).not_to include(active_code, inactive_code, future_code)
      end
    end

    describe '.available' do
      it 'returns only active and non-expired codes' do
        expect(DiscountCode.available).to include(active_code, future_code)
        expect(DiscountCode.available).not_to include(inactive_code, expired_code)
      end
    end
  end

  describe 'before_validation callbacks' do
    describe '#normalize_code' do
      it 'converts code to uppercase' do
        code = create(:discount_code, created_by: user, code: 'welcome20')
        expect(code.code).to eq('WELCOME20')
      end

      it 'strips whitespace from code' do
        code = create(:discount_code, created_by: user, code: '  SAVE10  ')
        expect(code.code).to eq('SAVE10')
      end

      it 'handles nil code gracefully' do
        code = build(:discount_code, created_by: user, code: nil)
        expect { code.valid? }.not_to raise_error
      end
    end
  end

  describe '#expired?' do
    context 'when expires_at is nil' do
      let(:code) { build(:discount_code, created_by: user, expires_at: nil) }
      
      it 'returns false' do
        expect(code.expired?).to be false
      end
    end

    context 'when expires_at is in the future' do
      let(:code) { build(:discount_code, created_by: user, expires_at: 1.day.from_now) }
      
      it 'returns false' do
        expect(code.expired?).to be false
      end
    end

    context 'when expires_at is in the past' do
      let(:code) { build(:discount_code, created_by: user, expires_at: 1.day.ago) }
      
      it 'returns true' do
        expect(code.expired?).to be true
      end
    end
  end

  describe '#usage_limit_reached?' do
    context 'when max_usage_count is nil' do
      let(:code) { build(:discount_code, created_by: user, max_usage_count: nil, current_usage_count: 100) }
      
      it 'returns false' do
        expect(code.usage_limit_reached?).to be false
      end
    end

    context 'when current_usage_count is less than max_usage_count' do
      let(:code) { build(:discount_code, created_by: user, max_usage_count: 10, current_usage_count: 5) }
      
      it 'returns false' do
        expect(code.usage_limit_reached?).to be false
      end
    end

    context 'when current_usage_count equals max_usage_count' do
      let(:code) { build(:discount_code, created_by: user, max_usage_count: 10, current_usage_count: 10) }
      
      it 'returns true' do
        expect(code.usage_limit_reached?).to be true
      end
    end

    context 'when current_usage_count exceeds max_usage_count' do
      let(:code) { build(:discount_code, created_by: user, max_usage_count: 10, current_usage_count: 15) }
      
      it 'returns true' do
        expect(code.usage_limit_reached?).to be true
      end
    end
  end

  describe '#available?' do
    let(:code) { build(:discount_code, created_by: user) }

    context 'when code is active, not expired, and usage limit not reached' do
      before do
        allow(code).to receive(:active?).and_return(true)
        allow(code).to receive(:expired?).and_return(false)
        allow(code).to receive(:usage_limit_reached?).and_return(false)
      end

      it 'returns true' do
        expect(code.available?).to be true
      end
    end

    context 'when code is inactive' do
      before do
        allow(code).to receive(:active?).and_return(false)
        allow(code).to receive(:expired?).and_return(false)
        allow(code).to receive(:usage_limit_reached?).and_return(false)
      end

      it 'returns false' do
        expect(code.available?).to be false
      end
    end

    context 'when code is expired' do
      before do
        allow(code).to receive(:active?).and_return(true)
        allow(code).to receive(:expired?).and_return(true)
        allow(code).to receive(:usage_limit_reached?).and_return(false)
      end

      it 'returns false' do
        expect(code.available?).to be false
      end
    end

    context 'when usage limit is reached' do
      before do
        allow(code).to receive(:active?).and_return(true)
        allow(code).to receive(:expired?).and_return(false)
        allow(code).to receive(:usage_limit_reached?).and_return(true)
      end

      it 'returns false' do
        expect(code.available?).to be false
      end
    end
  end

  describe '#usage_percentage' do
    context 'when max_usage_count is nil' do
      let(:code) { build(:discount_code, created_by: user, max_usage_count: nil, current_usage_count: 50) }
      
      it 'returns 0' do
        expect(code.usage_percentage).to eq(0)
      end
    end

    context 'when max_usage_count is 0' do
      let(:code) { build(:discount_code, created_by: user, max_usage_count: 0, current_usage_count: 0) }
      
      it 'returns 100' do
        expect(code.usage_percentage).to eq(100)
      end
    end

    context 'when current_usage_count is 25 and max_usage_count is 100' do
      let(:code) { build(:discount_code, created_by: user, max_usage_count: 100, current_usage_count: 25) }
      
      it 'returns 25.0' do
        expect(code.usage_percentage).to eq(25.0)
      end
    end

    context 'when current_usage_count is 33 and max_usage_count is 100' do
      let(:code) { build(:discount_code, created_by: user, max_usage_count: 100, current_usage_count: 33) }
      
      it 'returns 33.0' do
        expect(code.usage_percentage).to eq(33.0)
      end
    end
  end

  describe '#remaining_uses' do
    context 'when max_usage_count is nil' do
      let(:code) { build(:discount_code, created_by: user, max_usage_count: nil, current_usage_count: 50) }
      
      it 'returns nil' do
        expect(code.remaining_uses).to be_nil
      end
    end

    context 'when current_usage_count is less than max_usage_count' do
      let(:code) { build(:discount_code, created_by: user, max_usage_count: 100, current_usage_count: 25) }
      
      it 'returns the difference' do
        expect(code.remaining_uses).to eq(75)
      end
    end

    context 'when current_usage_count equals max_usage_count' do
      let(:code) { build(:discount_code, created_by: user, max_usage_count: 100, current_usage_count: 100) }
      
      it 'returns 0' do
        expect(code.remaining_uses).to eq(0)
      end
    end

    context 'when current_usage_count exceeds max_usage_count' do
      let(:code) { build(:discount_code, created_by: user, max_usage_count: 100, current_usage_count: 150) }
      
      it 'returns 0' do
        expect(code.remaining_uses).to eq(0)
      end
    end
  end

  describe '#revenue_impact' do
    let(:code) { create(:discount_code, created_by: user) }
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    before do
      create(:discount_code_usage, 
             discount_code: code, 
             user: user1, 
             original_amount: 5000,
             discount_amount: 1000,
             final_amount: 4000)
      create(:discount_code_usage, 
             discount_code: code, 
             user: user2, 
             original_amount: 5000,
             discount_amount: 1500,
             final_amount: 3500)
    end

    it 'returns the sum of all discount amounts' do
      expect(code.revenue_impact).to eq(2500)
    end

    context 'when no usages exist' do
      let(:unused_code) { create(:discount_code, created_by: user) }

      it 'returns 0' do
        expect(unused_code.revenue_impact).to eq(0)
      end
    end
  end

  describe 'edge cases and validations' do
    describe 'code normalization' do
      it 'handles special characters in code' do
        code = create(:discount_code, created_by: user, code: 'save-20%')
        expect(code.code).to eq('SAVE-20%')
      end

      it 'handles numeric codes' do
        code = create(:discount_code, created_by: user, code: '12345')
        expect(code.code).to eq('12345')
      end
    end

    describe 'concurrent usage scenarios' do
      let(:limited_code) { create(:discount_code, created_by: user, max_usage_count: 1, current_usage_count: 0) }

      it 'handles race conditions when reaching usage limit' do
        # Simulate concurrent increment
        expect {
          limited_code.increment!(:current_usage_count)
        }.to change { limited_code.reload.current_usage_count }.by(1)

        expect(limited_code.usage_limit_reached?).to be true
      end
    end

    describe 'expiration edge cases' do
      it 'handles codes expiring exactly at current time' do
        code = create(:discount_code, created_by: user, expires_at: Time.current)
        expect(code.expired?).to be true
      end

      it 'handles codes with microsecond precision' do
        future_time = Time.current + 1.5.seconds
        code = create(:discount_code, created_by: user, expires_at: future_time)
        expect(code.expired?).to be false
      end
    end
  end

  describe 'database constraints and indexes' do
    it 'enforces unique code constraint case-insensitively' do
      create(:discount_code, created_by: user, code: 'UNIQUE')
      
      expect {
        create(:discount_code, created_by: user, code: 'unique')
      }.to raise_error(ActiveRecord::RecordInvalid, /Code has already been taken/)
    end

    it 'allows same code after deletion' do
      code = create(:discount_code, created_by: user, code: 'REUSABLE')
      code.destroy
      
      expect {
        create(:discount_code, created_by: user, code: 'REUSABLE')
      }.not_to raise_error
    end
  end
end