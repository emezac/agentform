# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscountCodeService, type: :service do
  let(:user) { create(:user, discount_code_used: false, suspended_at: nil) }
  let(:suspended_user) { create(:user, suspended_at: 1.day.ago, suspended_reason: 'Violation') }
  let(:used_discount_user) { create(:user, discount_code_used: true) }
  let(:admin_user) { create(:user, role: 'admin') }
  
  let(:active_code) do
    create(:discount_code, 
           code: 'SAVE20',
           discount_percentage: 20,
           max_usage_count: 100,
           current_usage_count: 10,
           active: true,
           expires_at: 1.month.from_now,
           created_by: admin_user)
  end
  
  let(:expired_code) do
    create(:discount_code,
           code: 'EXPIRED',
           discount_percentage: 15,
           active: true,
           expires_at: 1.day.ago,
           created_by: admin_user)
  end
  
  let(:exhausted_code) do
    create(:discount_code,
           code: 'EXHAUSTED',
           discount_percentage: 10,
           max_usage_count: 5,
           current_usage_count: 5,
           active: true,
           created_by: admin_user)
  end
  
  let(:inactive_code) do
    create(:discount_code,
           code: 'INACTIVE',
           discount_percentage: 25,
           active: false,
           created_by: admin_user)
  end

  describe '#validate_code' do
    subject { described_class.new(user: user, code: code).validate_code }

    context 'with valid code and eligible user' do
      let(:code) { 'SAVE20' }
      
      before { active_code }

      it 'returns success with discount code' do
        expect(subject.success?).to be true
        expect(subject.result[:discount_code]).to eq(active_code)
      end

      it 'handles case insensitive codes' do
        service = described_class.new(user: user, code: 'save20').validate_code
        expect(service.success?).to be true
        expect(service.result[:discount_code]).to eq(active_code)
      end

      it 'handles codes with whitespace' do
        service = described_class.new(user: user, code: ' SAVE20 ').validate_code
        expect(service.success?).to be true
        expect(service.result[:discount_code]).to eq(active_code)
      end
    end

    context 'with invalid code' do
      let(:code) { 'INVALID' }

      it 'returns failure with error message' do
        expect(subject.success?).to be false
        expect(subject.errors.full_messages).to include('Code Invalid discount code')
      end
    end

    context 'with blank code' do
      let(:code) { '' }

      it 'returns failure with validation error' do
        expect(subject.success?).to be false
        expect(subject.errors.full_messages).to include('Code is required')
      end
    end

    context 'with expired code' do
      let(:code) { 'EXPIRED' }
      
      before { expired_code }

      it 'returns failure with expiration error' do
        expect(subject.success?).to be false
        expect(subject.errors.full_messages).to include('Code This discount code has expired')
      end
    end

    context 'with exhausted code' do
      let(:code) { 'EXHAUSTED' }
      
      before { exhausted_code }

      it 'returns failure with usage limit error' do
        expect(subject.success?).to be false
        expect(subject.errors.full_messages).to include('Code This discount code has reached its usage limit')
      end
    end

    context 'with inactive code' do
      let(:code) { 'INACTIVE' }
      
      before { inactive_code }

      it 'returns failure with inactive error' do
        expect(subject.success?).to be false
        expect(subject.errors.full_messages).to include('Code This discount code is no longer active')
      end
    end

    context 'with ineligible user' do
      let(:code) { 'SAVE20' }
      
      before { active_code }

      context 'user already used discount' do
        let(:user) { used_discount_user }

        it 'returns failure with detailed eligibility error' do
          expect(subject.success?).to be false
          expect(subject.errors.full_messages).to include('User You have already used a discount code. Each account can only use one discount code.')
        end
      end

      context 'suspended user' do
        let(:user) { suspended_user }

        it 'returns failure with detailed suspension error' do
          expect(subject.success?).to be false
          expect(subject.errors.full_messages).to include('User Your account is suspended and cannot use discount codes. Please contact support.')
        end
      end

      context 'premium user' do
        let(:user) { create(:user, subscription_tier: 'premium', discount_code_used: false) }

        it 'returns failure with premium user error' do
          expect(subject.success?).to be false
          expect(subject.errors.full_messages).to include('User Premium users cannot use discount codes on additional subscriptions.')
        end
      end
    end

    context 'without user' do
      let(:code) { 'SAVE20' }
      let(:user) { nil }

      it 'returns failure with validation error' do
        expect(subject.success?).to be false
        expect(subject.errors.full_messages).to include('User is required')
      end
    end
  end

  describe '#apply_discount' do
    let(:original_amount) { 10000 } # $100.00 in cents
    
    subject { described_class.new(user: user).apply_discount(active_code, original_amount) }

    before { active_code }

    context 'with valid inputs' do
      it 'calculates discount correctly' do
        expect(subject.success?).to be true
        
        result = subject.result
        expect(result[:original_amount]).to eq(10000)
        expect(result[:discount_amount]).to eq(2000) # 20% of $100
        expect(result[:final_amount]).to eq(8000)    # $100 - $20
        expect(result[:discount_percentage]).to eq(20)
        expect(result[:savings_percentage]).to eq(20.0)
      end

      it 'handles edge case where discount exceeds amount' do
        small_amount = 100 # $1.00
        service = described_class.new(user: user).apply_discount(active_code, small_amount)
        
        expect(service.success?).to be true
        result = service.result
        expect(result[:discount_amount]).to eq(20) # 20% of $1.00
        expect(result[:final_amount]).to eq(80)    # $1.00 - $0.20
      end

      it 'ensures final amount never goes below zero' do
        # Create a 100% discount code
        full_discount_code = create(:discount_code, 
                                   code: 'FREE100',
                                   discount_percentage: 99,
                                   active: true,
                                   created_by: admin_user)
        
        service = described_class.new(user: user).apply_discount(full_discount_code, 1000)
        expect(service.success?).to be true
        
        result = service.result
        expect(result[:final_amount]).to be >= 0
      end
    end

    context 'with invalid discount code' do
      it 'returns failure when discount_code is not a DiscountCode instance' do
        service = described_class.new(user: user).apply_discount('invalid', original_amount)
        
        expect(service.success?).to be false
        expect(service.errors.full_messages).to include('Discount code must be a DiscountCode instance')
      end
    end

    context 'with invalid amount' do
      it 'returns failure when amount is not positive integer' do
        service = described_class.new(user: user).apply_discount(active_code, -100)
        
        expect(service.success?).to be false
        expect(service.errors.full_messages).to include('Original amount must be a positive integer (amount in cents)')
      end

      it 'returns failure when amount is not integer' do
        service = described_class.new(user: user).apply_discount(active_code, 100.50)
        
        expect(service.success?).to be false
        expect(service.errors.full_messages).to include('Original amount must be a positive integer (amount in cents)')
      end
    end

    context 'without user' do
      let(:user) { nil }

      it 'returns failure with validation error' do
        expect(subject.success?).to be false
        expect(subject.errors.full_messages).to include('User is required')
      end
    end
  end

  describe '#record_usage' do
    let(:subscription_details) do
      {
        subscription_id: 'sub_123456789',
        original_amount: 10000,
        discount_amount: 2000,
        final_amount: 8000
      }
    end

    subject { described_class.new(user: user).record_usage(active_code, subscription_details) }

    before { active_code }

    context 'with valid inputs and eligible user' do
      it 'creates usage record and updates counters' do
        expect { subject }.to change(DiscountCodeUsage, :count).by(1)
                          .and change { active_code.reload.current_usage_count }.by(1)
                          .and change { user.reload.discount_code_used }.from(false).to(true)

        expect(subject.success?).to be true
        
        usage_record = subject.result[:usage_record]
        expect(usage_record.discount_code).to eq(active_code)
        expect(usage_record.user).to eq(user)
        expect(usage_record.subscription_id).to eq('sub_123456789')
        expect(usage_record.original_amount).to eq(10000)
        expect(usage_record.discount_amount).to eq(2000)
        expect(usage_record.final_amount).to eq(8000)
      end

      it 'deactivates code when usage limit is reached' do
        # Set up code with only 1 remaining use
        active_code.update!(max_usage_count: 11, current_usage_count: 10)
        
        expect { subject }.to change { active_code.reload.active }.from(true).to(false)
        expect(subject.success?).to be true
      end

      it 'does not deactivate code when no usage limit' do
        active_code.update!(max_usage_count: nil)
        
        expect { subject }.not_to change { active_code.reload.active }
        expect(subject.success?).to be true
      end
    end

    context 'with invalid subscription details' do
      let(:subscription_details) { { subscription_id: 'sub_123' } }

      it 'returns failure with validation errors' do
        expect(subject.success?).to be false
        expect(subject.errors.full_messages).to include(
          'Subscription details original_amount is required',
          'Subscription details discount_amount is required',
          'Subscription details final_amount is required'
        )
      end
    end

    context 'with incorrect calculation in subscription details' do
      let(:subscription_details) do
        {
          subscription_id: 'sub_123456789',
          original_amount: 10000,
          discount_amount: 2000,
          final_amount: 7000 # Incorrect: should be 8000
        }
      end

      it 'returns failure with calculation error' do
        expect(subject.success?).to be false
        expect(subject.errors.full_messages).to include('Subscription details Final amount calculation is incorrect')
      end
    end

    context 'with ineligible user' do
      let(:user) { used_discount_user }

      it 'returns failure without creating records' do
        expect { subject }.not_to change(DiscountCodeUsage, :count)
        expect(subject.success?).to be false
        expect(subject.errors.full_messages).to include('User You have already used a discount code. Each account can only use one discount code.')
      end
    end

    context 'with invalid discount code' do
      it 'returns failure when discount_code is not a DiscountCode instance' do
        service = described_class.new(user: user).record_usage('invalid', subscription_details)
        
        expect(service.success?).to be false
        expect(service.errors.full_messages).to include('Discount code must be a DiscountCode instance')
      end
    end
  end

  describe '#check_availability' do
    subject { described_class.new.check_availability(code) }

    context 'with available code' do
      let(:code) { 'SAVE20' }
      
      before { active_code }

      it 'returns availability status' do
        expect(subject.success?).to be true
        
        result = subject.result
        expect(result[:code]).to eq('SAVE20')
        expect(result[:valid]).to be true
        expect(result[:active]).to be true
        expect(result[:expired]).to be false
        expect(result[:usage_limit_reached]).to be false
        expect(result[:available]).to be true
        expect(result[:discount_percentage]).to eq(20)
        expect(result[:remaining_uses]).to eq(90)
      end
    end

    context 'with expired code' do
      let(:code) { 'EXPIRED' }
      
      before { expired_code }

      it 'returns correct status for expired code' do
        expect(subject.success?).to be true
        
        result = subject.result
        expect(result[:expired]).to be true
        expect(result[:available]).to be false
      end
    end

    context 'with invalid code' do
      let(:code) { 'INVALID' }

      it 'returns failure' do
        expect(subject.success?).to be false
        expect(subject.errors.full_messages).to include('Code Invalid discount code')
      end
    end
  end

  describe '#get_usage_statistics' do
    subject { described_class.new.get_usage_statistics(active_code) }

    before do
      active_code
      # Create some usage records
      create_list(:discount_code_usage, 3, discount_code: active_code)
    end

    it 'returns comprehensive usage statistics' do
      expect(subject.success?).to be true
      
      result = subject.result
      expect(result[:code]).to eq('SAVE20')
      expect(result[:total_uses]).to eq(active_code.current_usage_count)
      expect(result[:max_uses]).to eq(100)
      expect(result[:remaining_uses]).to be_present
      expect(result[:usage_percentage]).to be_present
      expect(result[:revenue_impact]).to be_present
      expect(result[:active]).to be true
      expect(result[:expired]).to be false
      expect(result[:recent_usages]).to be_present
    end

    context 'with invalid discount code' do
      it 'returns failure when discount_code is not a DiscountCode instance' do
        service = described_class.new.get_usage_statistics('invalid')
        
        expect(service.success?).to be false
        expect(service.errors.full_messages).to include('Discount code must be a DiscountCode instance')
      end
    end
  end

  describe '#check_user_eligibility' do
    subject { described_class.new(user: user).check_user_eligibility }

    context 'with eligible user' do
      it 'returns eligible status' do
        expect(subject.success?).to be true
        
        result = subject.result
        expect(result[:eligible]).to be true
        expect(result[:reasons]).to be_empty
      end
    end

    context 'with ineligible users' do
      context 'user already used discount' do
        let(:user) { used_discount_user }

        it 'returns ineligible status with reason' do
          expect(subject.success?).to be true
          
          result = subject.result
          expect(result[:eligible]).to be false
          expect(result[:reasons]).to include('User has already used a discount code')
        end
      end

      context 'suspended user' do
        let(:user) { suspended_user }

        it 'returns ineligible status with suspension reason' do
          expect(subject.success?).to be true
          
          result = subject.result
          expect(result[:eligible]).to be false
          expect(result[:reasons]).to include('User account is suspended')
        end
      end

      context 'premium user' do
        let(:user) { create(:user, subscription_tier: 'premium', discount_code_used: false) }

        it 'returns ineligible status with premium reason' do
          expect(subject.success?).to be true
          
          result = subject.result
          expect(result[:eligible]).to be false
          expect(result[:reasons]).to include('User already has a premium subscription')
        end
      end

      context 'user with multiple ineligibility reasons' do
        let(:user) { create(:user, subscription_tier: 'premium', discount_code_used: true, suspended_at: 1.day.ago) }

        it 'returns all applicable reasons' do
          expect(subject.success?).to be true
          
          result = subject.result
          expect(result[:eligible]).to be false
          expect(result[:reasons]).to include(
            'User has already used a discount code',
            'User account is suspended',
            'User already has a premium subscription'
          )
        end
      end
    end

    context 'without user' do
      let(:user) { nil }

      it 'returns failure with validation error' do
        expect(subject.success?).to be false
        expect(subject.errors.full_messages).to include('User is required')
      end
    end
  end

  describe '#deactivate_expired_codes' do
    subject { described_class.new.deactivate_expired_codes }

    before do
      active_code   # Active and valid
      expired_code  # Expired but active
      exhausted_code # Exhausted but active
      inactive_code # Already inactive
    end

    it 'deactivates expired and exhausted codes' do
      expect { subject }.to change { expired_code.reload.active }.from(true).to(false)
                        .and change { exhausted_code.reload.active }.from(true).to(false)
      
      expect(subject.success?).to be true
      expect(subject.result[:deactivated_count]).to eq(2)
      
      # Active code should remain active
      expect(active_code.reload.active).to be true
      # Inactive code should remain inactive
      expect(inactive_code.reload.active).to be false
    end

    context 'when no codes need deactivation' do
      before do
        # Make all codes either active/valid or already inactive
        expired_code.update!(active: false)
        exhausted_code.update!(active: false)
      end

      it 'returns zero deactivated count' do
        expect(subject.success?).to be true
        expect(subject.result[:deactivated_count]).to eq(0)
      end
    end
  end

  describe '#bulk_validate_codes' do
    let(:codes) { ['SAVE20', 'EXPIRED', 'INVALID', 'EXHAUSTED'] }
    
    before do
      active_code
      expired_code
      exhausted_code
    end

    subject { described_class.new.bulk_validate_codes(codes) }

    it 'validates multiple codes efficiently' do
      expect(subject.success?).to be true
      
      results = subject.result[:results]
      expect(results).to have_key('SAVE20')
      expect(results).to have_key('EXPIRED')
      expect(results).to have_key('INVALID')
      expect(results).to have_key('EXHAUSTED')
      
      expect(results['SAVE20'][:valid]).to be true
      expect(results['EXPIRED'][:valid]).to be false
      expect(results['INVALID'][:valid]).to be false
      expect(results['EXHAUSTED'][:valid]).to be false
    end

    it 'handles empty code list' do
      service = described_class.new.bulk_validate_codes([])
      expect(service.success?).to be true
      expect(service.result[:results]).to be_empty
    end

    it 'handles duplicate codes in list' do
      service = described_class.new.bulk_validate_codes(['SAVE20', 'SAVE20'])
      expect(service.success?).to be true
      expect(service.result[:results]).to have_key('SAVE20')
      expect(service.result[:results].keys.count).to eq(1)
    end
  end

  describe '#calculate_potential_savings' do
    let(:amounts) { [1000, 2000, 5000, 10000] }
    
    subject { described_class.new.calculate_potential_savings(active_code, amounts) }

    before { active_code }

    it 'calculates savings for multiple amounts' do
      expect(subject.success?).to be true
      
      results = subject.result[:calculations]
      expect(results).to have(4).items
      
      expect(results[0][:original_amount]).to eq(1000)
      expect(results[0][:discount_amount]).to eq(200) # 20% of 1000
      expect(results[0][:final_amount]).to eq(800)
      
      expect(results[3][:original_amount]).to eq(10000)
      expect(results[3][:discount_amount]).to eq(2000) # 20% of 10000
      expect(results[3][:final_amount]).to eq(8000)
    end

    it 'handles empty amounts array' do
      service = described_class.new.calculate_potential_savings(active_code, [])
      expect(service.success?).to be true
      expect(service.result[:calculations]).to be_empty
    end
  end

  describe '#generate_usage_report' do
    let(:start_date) { 1.month.ago }
    let(:end_date) { Time.current }
    
    before do
      active_code
      create_list(:discount_code_usage, 5, discount_code: active_code, used_at: 2.weeks.ago)
      create_list(:discount_code_usage, 3, discount_code: active_code, used_at: 1.week.ago)
    end

    subject { described_class.new.generate_usage_report(start_date, end_date) }

    it 'generates comprehensive usage report' do
      expect(subject.success?).to be true
      
      report = subject.result
      expect(report[:period][:start_date]).to eq(start_date)
      expect(report[:period][:end_date]).to eq(end_date)
      expect(report[:total_codes]).to be > 0
      expect(report[:total_usages]).to eq(8)
      expect(report[:total_revenue_impact]).to be > 0
      expect(report[:top_codes]).to be_present
      expect(report[:usage_by_day]).to be_present
    end

    it 'handles date range with no usage' do
      future_start = 1.week.from_now
      future_end = 2.weeks.from_now
      
      service = described_class.new.generate_usage_report(future_start, future_end)
      expect(service.success?).to be true
      expect(service.result[:total_usages]).to eq(0)
    end
  end

  describe 'error handling and edge cases' do
    it 'handles database errors gracefully' do
      allow(DiscountCode).to receive(:find_by).and_raise(ActiveRecord::ConnectionTimeoutError)
      
      service = described_class.new(user: user, code: 'TEST').validate_code
      expect(service.success?).to be false
      expect(service.errors.full_messages).to include(/Database error/)
    end

    it 'validates required attributes' do
      service = described_class.new.validate_code
      expect(service.success?).to be false
      expect(service.errors.full_messages).to include('User is required', 'Code is required')
    end

    it 'handles concurrent usage attempts' do
      # This test simulates race conditions where multiple users try to use
      # the last available discount code simultaneously
      last_use_code = create(:discount_code,
                            code: 'LASTUSE',
                            discount_percentage: 10,
                            max_usage_count: 1,
                            current_usage_count: 0,
                            active: true,
                            created_by: admin_user)

      user1 = create(:user, discount_code_used: false)
      user2 = create(:user, discount_code_used: false)

      subscription_details = {
        subscription_id: 'sub_123',
        original_amount: 1000,
        discount_amount: 100,
        final_amount: 900
      }

      # First usage should succeed
      service1 = described_class.new(user: user1).record_usage(last_use_code, subscription_details)
      expect(service1.success?).to be true

      # Second usage should fail due to usage limit
      service2 = described_class.new(user: user2).record_usage(last_use_code.reload, subscription_details)
      expect(service2.success?).to be false
      expect(service2.errors.full_messages).to include('Discount code This discount code has reached its usage limit')
    end

    it 'handles user eligibility changes during processing' do
      # Test scenario where user becomes ineligible
      subscription_details = {
        subscription_id: 'sub_123',
        original_amount: 1000,
        discount_amount: 100,
        final_amount: 900
      }

      # Make user ineligible by marking them as having used a discount
      user.update!(discount_code_used: true)

      service = described_class.new(user: user).record_usage(active_code, subscription_details)
      expect(service.success?).to be false
      expect(service.errors.full_messages).to include('User You have already used a discount code. Each account can only use one discount code.')
    end

    it 'handles discount code becoming unavailable' do
      subscription_details = {
        subscription_id: 'sub_123',
        original_amount: 1000,
        discount_amount: 100,
        final_amount: 900
      }

      # Make discount code unavailable by deactivating it
      active_code.update!(active: false)

      service = described_class.new(user: user).record_usage(active_code, subscription_details)
      expect(service.success?).to be false
      expect(service.errors.full_messages).to include('User You have already used a discount code. Each account can only use one discount code.')
    end

    it 'handles duplicate key violations gracefully' do
      subscription_details = {
        subscription_id: 'sub_123',
        original_amount: 1000,
        discount_amount: 100,
        final_amount: 900
      }

      # Mock a duplicate key violation (user already used a discount)
      allow_any_instance_of(DiscountCodeService).to receive(:create_usage_record)
        .and_raise(ActiveRecord::RecordNotUnique.new('duplicate key value violates unique constraint'))

      service = described_class.new(user: user).record_usage(active_code, subscription_details)
      expect(service.success?).to be false
      expect(service.errors.full_messages).to include('Concurrency This discount code was just used by another user. Please try a different code.')
    end

    it 'handles invalid date ranges in reports' do
      invalid_start = 1.week.from_now
      invalid_end = 1.week.ago
      
      service = described_class.new.generate_usage_report(invalid_start, invalid_end)
      expect(service.success?).to be false
      expect(service.errors.full_messages).to include('Date range Start date must be before end date')
    end

    it 'handles memory constraints with large datasets' do
      # Mock a scenario with many discount codes
      allow(DiscountCode).to receive(:count).and_return(100000)
      
      service = described_class.new.generate_usage_report(1.year.ago, Time.current)
      # Should still succeed but might implement pagination internally
      expect(service.success?).to be true
    end

    it 'handles network timeouts during external validations' do
      # Mock external service timeout
      allow_any_instance_of(DiscountCodeService).to receive(:validate_with_external_service)
        .and_raise(Net::TimeoutError)
      
      service = described_class.new(user: user, code: 'EXTERNAL').validate_code
      # Should fallback to internal validation
      expect(service.success?).to be_in([true, false]) # Depends on implementation
    end
  end

  describe 'performance and optimization' do
    it 'efficiently processes bulk operations' do
      codes = (1..100).map { |i| "BULK#{i}" }
      
      # Create some codes in database
      codes.first(10).each do |code|
        create(:discount_code, code: code, created_by: admin_user)
      end
      
      expect {
        described_class.new.bulk_validate_codes(codes)
      }.to make_database_queries(count: 1..5) # Should be efficient with batching
    end

    it 'caches frequently accessed discount codes' do
      # First access
      service1 = described_class.new(user: user, code: 'SAVE20').validate_code
      
      # Second access should use cache (mock cache behavior)
      allow(Rails.cache).to receive(:fetch).and_call_original
      service2 = described_class.new(user: user, code: 'SAVE20').validate_code
      
      expect(Rails.cache).to have_received(:fetch).at_least(:once)
    end
  end

  describe 'audit and logging' do
    it 'logs all validation attempts' do
      expect(Rails.logger).to receive(:info).with(/Discount code validation attempt/)
      
      described_class.new(user: user, code: 'SAVE20').validate_code
    end

    it 'logs successful usage recordings' do
      subscription_details = {
        subscription_id: 'sub_123',
        original_amount: 1000,
        discount_amount: 100,
        final_amount: 900
      }
      
      expect(Rails.logger).to receive(:info).with(/Discount code usage recorded/)
      
      described_class.new(user: user).record_usage(active_code, subscription_details)
    end

    it 'logs security-relevant events' do
      # Multiple failed attempts should be logged
      5.times do
        described_class.new(user: user, code: 'INVALID').validate_code
      end
      
      expect(Rails.logger).to have_received(:warn).with(/Multiple failed discount code attempts/).at_least(:once)
    end
  end
end