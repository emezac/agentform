# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Discount Code Performance', type: :request do
  let(:superadmin) { create(:user, role: 'superadmin') }
  let(:regular_user) { create(:user, role: 'user') }

  describe 'Database query optimization' do
    before do
      # Create test data
      create_list(:discount_code, 100, created_by: superadmin)
      create_list(:user, 50)
      create_list(:discount_code_usage, 200)
    end

    it 'efficiently loads discount codes with usage statistics' do
      sign_in superadmin

      expect {
        get '/admin/discount_codes'
      }.to make_database_queries(count: 1..5)

      expect(response).to have_http_status(:success)
    end

    it 'efficiently loads user listings with related data' do
      sign_in superadmin

      expect {
        get '/admin/users'
      }.to make_database_queries(count: 1..5)

      expect(response).to have_http_status(:success)
    end

    it 'optimizes discount code validation queries' do
      sign_in regular_user

      expect {
        post '/api/v1/discount_codes/validate', params: {
          code: 'DISCOUNT1',
          billing_cycle: 'monthly'
        }
      }.to make_database_queries(count: 1..3)
    end

    it 'efficiently handles bulk operations' do
      sign_in superadmin
      discount_codes = DiscountCode.limit(10)

      expect {
        patch '/admin/discount_codes/bulk_update', params: {
          discount_code_ids: discount_codes.pluck(:id),
          action: 'deactivate'
        }
      }.to make_database_queries(count: 1..5)
    end
  end

  describe 'Response time benchmarks' do
    before do
      sign_in regular_user
    end

    it 'validates discount codes within acceptable time limits' do
      discount_code = create(:discount_code, created_by: superadmin)

      benchmark = Benchmark.measure do
        post '/api/v1/discount_codes/validate', params: {
          code: discount_code.code,
          billing_cycle: 'monthly'
        }
      end

      # Should respond within 200ms
      expect(benchmark.real).to be < 0.2
      expect(response).to have_http_status(:success)
    end

    it 'handles concurrent validation requests efficiently' do
      discount_code = create(:discount_code, created_by: superadmin)
      
      threads = []
      response_times = []

      10.times do
        threads << Thread.new do
          start_time = Time.current
          
          post '/api/v1/discount_codes/validate', params: {
            code: discount_code.code,
            billing_cycle: 'monthly'
          }
          
          response_times << Time.current - start_time
        end
      end

      threads.each(&:join)

      # All requests should complete within reasonable time
      expect(response_times.max).to be < 1.0
      expect(response_times.average).to be < 0.5
    end

    it 'maintains performance under load' do
      discount_codes = create_list(:discount_code, 10, created_by: superadmin)
      
      # Simulate load testing
      total_time = Benchmark.measure do
        100.times do |i|
          code = discount_codes[i % 10]
          
          post '/api/v1/discount_codes/validate', params: {
            code: code.code,
            billing_cycle: 'monthly'
          }
        end
      end

      # Average response time should remain acceptable
      average_time = total_time.real / 100
      expect(average_time).to be < 0.1
    end
  end

  describe 'Memory usage optimization' do
    it 'efficiently handles large datasets without memory bloat' do
      # Create large dataset
      create_list(:discount_code, 1000, created_by: superadmin)
      create_list(:discount_code_usage, 5000)

      sign_in superadmin

      # Monitor memory usage
      initial_memory = get_memory_usage

      # Load large dataset
      get '/admin/discount_codes', params: { per_page: 100 }
      expect(response).to have_http_status(:success)

      # Memory usage should not increase dramatically
      final_memory = get_memory_usage
      memory_increase = final_memory - initial_memory

      # Should not use more than 50MB additional memory
      expect(memory_increase).to be < 50.megabytes
    end

    it 'properly garbage collects after bulk operations' do
      discount_codes = create_list(:discount_code, 100, created_by: superadmin)
      
      sign_in superadmin

      initial_memory = get_memory_usage

      # Perform bulk operation
      patch '/admin/discount_codes/bulk_update', params: {
        discount_code_ids: discount_codes.pluck(:id),
        action: 'deactivate'
      }

      # Force garbage collection
      GC.start

      final_memory = get_memory_usage
      memory_increase = final_memory - initial_memory

      # Memory should not increase significantly after GC
      expect(memory_increase).to be < 20.megabytes
    end
  end

  describe 'Caching effectiveness' do
    before do
      sign_in regular_user
    end

    it 'caches frequently accessed discount codes' do
      discount_code = create(:discount_code, created_by: superadmin)

      # First request should hit database
      expect(Rails.cache).to receive(:fetch).with(/discount_code_#{discount_code.code}/).and_call_original

      post '/api/v1/discount_codes/validate', params: {
        code: discount_code.code,
        billing_cycle: 'monthly'
      }

      # Second request should use cache
      expect(Rails.cache).to receive(:fetch).with(/discount_code_#{discount_code.code}/).and_return(discount_code)

      post '/api/v1/discount_codes/validate', params: {
        code: discount_code.code,
        billing_cycle: 'monthly'
      }
    end

    it 'invalidates cache when discount codes are modified' do
      discount_code = create(:discount_code, created_by: superadmin)

      # Cache the discount code
      post '/api/v1/discount_codes/validate', params: {
        code: discount_code.code,
        billing_cycle: 'monthly'
      }

      sign_in superadmin

      # Modify the discount code
      patch "/admin/discount_codes/#{discount_code.id}", params: {
        discount_code: { discount_percentage: 30 }
      }

      # Cache should be invalidated
      expect(Rails.cache.exist?("discount_code_#{discount_code.code}")).to be false
    end

    it 'caches user eligibility checks' do
      # First eligibility check should cache result
      expect(Rails.cache).to receive(:fetch).with(/user_#{regular_user.id}_discount_eligibility/).and_call_original

      post '/api/v1/discount_codes/validate', params: {
        code: 'TESTCODE',
        billing_cycle: 'monthly'
      }

      # Subsequent checks should use cache
      expect(Rails.cache).to receive(:fetch).with(/user_#{regular_user.id}_discount_eligibility/).and_return(true)

      post '/api/v1/discount_codes/validate', params: {
        code: 'TESTCODE2',
        billing_cycle: 'monthly'
      }
    end
  end

  describe 'Pagination and data loading' do
    before do
      create_list(:discount_code, 250, created_by: superadmin)
      sign_in superadmin
    end

    it 'efficiently paginates large datasets' do
      # Test different page sizes
      [10, 25, 50, 100].each do |per_page|
        benchmark = Benchmark.measure do
          get '/admin/discount_codes', params: { per_page: per_page, page: 1 }
        end

        expect(response).to have_http_status(:success)
        expect(benchmark.real).to be < 0.5 # Should load within 500ms regardless of page size
      end
    end

    it 'maintains consistent performance across pages' do
      page_times = []

      # Test first, middle, and last pages
      [1, 5, 10].each do |page|
        benchmark = Benchmark.measure do
          get '/admin/discount_codes', params: { per_page: 25, page: page }
        end

        page_times << benchmark.real
        expect(response).to have_http_status(:success)
      end

      # Performance should be consistent across pages
      time_variance = page_times.max - page_times.min
      expect(time_variance).to be < 0.1 # Less than 100ms variance
    end
  end

  describe 'Search and filtering performance' do
    before do
      # Create diverse test data
      create_list(:discount_code, 100, created_by: superadmin)
      create_list(:user, 200)
      sign_in superadmin
    end

    it 'efficiently handles text search queries' do
      benchmark = Benchmark.measure do
        get '/admin/discount_codes', params: { search: 'DISCOUNT' }
      end

      expect(response).to have_http_status(:success)
      expect(benchmark.real).to be < 0.3
    end

    it 'efficiently handles complex filter combinations' do
      benchmark = Benchmark.measure do
        get '/admin/discount_codes', params: {
          status: 'active',
          created_after: 1.week.ago.to_date,
          usage_above: 10
        }
      end

      expect(response).to have_http_status(:success)
      expect(benchmark.real).to be < 0.5
    end

    it 'optimizes user search queries' do
      benchmark = Benchmark.measure do
        get '/admin/users', params: {
          search: 'user',
          role: 'user',
          subscription_tier: 'freemium'
        }
      end

      expect(response).to have_http_status(:success)
      expect(benchmark.real).to be < 0.4
    end
  end

  describe 'Background job performance' do
    it 'efficiently processes discount code cleanup jobs' do
      # Create expired and exhausted codes
      create_list(:discount_code, 50, expires_at: 1.day.ago, active: true)
      create_list(:discount_code, 50, max_usage_count: 1, current_usage_count: 1, active: true)

      benchmark = Benchmark.measure do
        DiscountCodeCleanupJob.perform_now
      end

      # Should complete within reasonable time
      expect(benchmark.real).to be < 5.0

      # Should properly deactivate codes
      expect(DiscountCode.where(active: false).count).to be >= 100
    end

    it 'efficiently processes user invitation jobs' do
      users_to_invite = create_list(:user, 20)

      benchmark = Benchmark.measure do
        users_to_invite.each do |user|
          UserInvitationJob.perform_now(user)
        end
      end

      # Should process all invitations efficiently
      expect(benchmark.real).to be < 10.0
    end
  end

  describe 'API rate limiting performance' do
    before do
      sign_in regular_user
    end

    it 'efficiently tracks rate limit counters' do
      discount_code = create(:discount_code, created_by: superadmin)

      # Make requests up to rate limit
      benchmark = Benchmark.measure do
        10.times do
          post '/api/v1/discount_codes/validate', params: {
            code: discount_code.code,
            billing_cycle: 'monthly'
          }
        end
      end

      # Rate limiting overhead should be minimal
      average_time = benchmark.real / 10
      expect(average_time).to be < 0.1
    end

    it 'efficiently handles rate limit storage and retrieval' do
      # Test Redis-based rate limiting performance
      user_key = "rate_limit:user:#{regular_user.id}"

      benchmark = Benchmark.measure do
        100.times do
          Rails.cache.increment(user_key, 1, expires_in: 1.hour)
          Rails.cache.read(user_key)
        end
      end

      # Cache operations should be fast
      expect(benchmark.real).to be < 0.5
    end
  end

  private

  def get_memory_usage
    # Get current memory usage in bytes
    `ps -o rss= -p #{Process.pid}`.to_i * 1024
  end
end

# Helper to calculate array average
class Array
  def average
    sum.to_f / length
  end
end