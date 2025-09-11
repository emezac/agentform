# frozen_string_literal: true

namespace :pagination do
  desc "Verify pagination configuration and dependencies"
  task verify: :environment do
    puts "🔍 Pagination Configuration Verification"
    puts "=" * 50
    puts "Environment: #{Rails.env}"
    puts "Timestamp: #{Time.current}"
    puts

    # Get diagnostic information
    diagnostic_info = PaginationStatus.diagnostic_info
    
    puts "📊 System Status:"
    puts "  Kaminari Available: #{diagnostic_info[:kaminari_available] ? '✅' : '❌'}"
    puts "  Kaminari Version: #{diagnostic_info[:kaminari_version] || 'N/A'}"
    puts "  ActiveRecord Integration: #{diagnostic_info[:activerecord_integration] ? '✅' : '❌'}"
    puts "  ActionView Integration: #{diagnostic_info[:actionview_integration] ? '✅' : '❌'}"
    puts "  Fully Operational: #{diagnostic_info[:fully_operational] ? '✅' : '❌'}"
    puts "  Fallback Mode: #{diagnostic_info[:fallback_mode] ? '⚠️  Yes' : 'No'}"
    puts

    if diagnostic_info[:errors].any?
      puts "❌ Issues Found:"
      diagnostic_info[:errors].each do |error|
        puts "  - #{error}"
      end
      puts
    end

    # Test pagination functionality
    puts "🧪 Functionality Tests:"
    test_pagination_functionality
    
    puts
    puts "📋 Recommendations:"
    provide_recommendations(diagnostic_info)
  end

  desc "Show current pagination status"
  task status: :environment do
    status = PaginationStatus.diagnostic_info
    
    puts "Pagination Status: #{status[:fully_operational] ? 'Operational' : 'Fallback Mode'}"
    puts "Kaminari: #{status[:kaminari_available] ? "v#{status[:kaminari_version]}" : 'Not Available'}"
    puts "Mode: #{status[:fallback_mode] ? 'Fallback' : 'Full'}"
  end

  desc "Test pagination with sample data"
  task test: :environment do
    puts "🧪 Testing Pagination Functionality"
    puts "=" * 40
    
    # Create a test controller instance to test SafePagination
    test_controller = Class.new(ApplicationController) do
      include SafePagination
      
      def test_pagination
        if defined?(User)
          users = safe_paginate(User.all, page: 1, per_page: 5)
          {
            total_count: users.total_count,
            current_page: users.current_page,
            total_pages: users.total_pages,
            has_next: users.respond_to?(:next_page) ? !users.next_page.nil? : false,
            method_used: defined?(Kaminari) && User.all.respond_to?(:page) ? 'Kaminari' : 'Fallback'
          }
        else
          { error: "User model not available for testing" }
        end
      end
    end.new
    
    begin
      result = test_controller.test_pagination
      
      if result[:error]
        puts "❌ #{result[:error]}"
      else
        puts "✅ Pagination test successful"
        puts "  Method used: #{result[:method_used]}"
        puts "  Total records: #{result[:total_count]}"
        puts "  Current page: #{result[:current_page]}"
        puts "  Total pages: #{result[:total_pages]}"
        puts "  Has next page: #{result[:has_next]}"
      end
      
    rescue => e
      puts "❌ Pagination test failed: #{e.message}"
      puts "  This indicates a problem with the pagination system"
    end
  end

  desc "Show detailed diagnostic information"
  task diagnose: :environment do
    puts "🔬 Detailed Pagination Diagnostics"
    puts "=" * 50
    
    # Environment information
    puts "Environment Information:"
    puts "  Rails version: #{Rails.version}"
    puts "  Ruby version: #{RUBY_VERSION}"
    puts "  Environment: #{Rails.env}"
    puts

    # Gem information
    puts "Gem Information:"
    if defined?(Bundler)
      begin
        kaminari_spec = Bundler.load.specs.find { |spec| spec.name == 'kaminari' }
        if kaminari_spec
          puts "  Kaminari gem: v#{kaminari_spec.version} (#{kaminari_spec.loaded_from})"
        else
          puts "  Kaminari gem: Not found in bundle"
        end
      rescue => e
        puts "  Kaminari gem: Error checking bundle (#{e.message})"
      end
    else
      puts "  Bundler not available"
    end
    puts

    # Load path information
    puts "Load Path Information:"
    kaminari_paths = $LOAD_PATH.select { |path| path.include?('kaminari') }
    if kaminari_paths.any?
      puts "  Kaminari in load path:"
      kaminari_paths.each { |path| puts "    #{path}" }
    else
      puts "  Kaminari not found in load path"
    end
    puts

    # ActiveRecord integration
    puts "ActiveRecord Integration:"
    if defined?(ActiveRecord::Base)
      puts "  ActiveRecord available: ✅"
      
      # Test if we can create a relation
      begin
        if defined?(User)
          relation = User.limit(1)
          puts "  Can create relations: ✅"
          puts "  Relation responds to .page: #{relation.respond_to?(:page) ? '✅' : '❌'}"
          
          if relation.respond_to?(:page)
            puts "  .page method source: #{relation.method(:page).source_location}"
          end
        else
          puts "  User model not available for testing"
        end
      rescue => e
        puts "  Error testing relations: #{e.message}"
      end
    else
      puts "  ActiveRecord not available: ❌"
    end
    puts

    # ActionView integration
    puts "ActionView Integration:"
    if defined?(ActionView::Base)
      puts "  ActionView available: ✅"
      puts "  Paginate helper available: #{ActionView::Base.instance_methods.include?(:paginate) ? '✅' : '❌'}"
    else
      puts "  ActionView not available: ❌"
    end
    puts

    # Configuration status
    diagnostic_info = PaginationStatus.diagnostic_info
    puts "Current Status:"
    puts "  #{diagnostic_info[:fully_operational] ? '✅' : '❌'} System fully operational"
    puts "  #{diagnostic_info[:fallback_mode] ? '⚠️' : '✅'} #{diagnostic_info[:fallback_mode] ? 'Using fallback mode' : 'Using full pagination'}"
  end

  private

  def test_pagination_functionality
    # Test SafePagination concern
    begin
      test_controller = Class.new do
        include SafePagination
        
        def action_name
          'test'
        end
        
        def self.name
          'TestController'
        end
      end.new
      
      # Create a mock relation
      mock_relation = double('ActiveRecord::Relation')
      allow(mock_relation).to receive(:limit).and_return(mock_relation)
      allow(mock_relation).to receive(:offset).and_return(mock_relation)
      allow(mock_relation).to receive(:count).and_return(100)
      allow(mock_relation).to receive(:to_a).and_return([])
      
      result = test_controller.send(:safe_paginate, mock_relation, page: 1, per_page: 10)
      
      puts "  SafePagination concern: ✅ Working"
      puts "  Fallback pagination: ✅ Functional"
      
    rescue => e
      puts "  SafePagination concern: ❌ Error (#{e.message})"
    end
    
    # Test Kaminari if available
    if defined?(Kaminari) && defined?(User)
      begin
        User.page(1).per(5)
        puts "  Kaminari pagination: ✅ Working"
      rescue => e
        puts "  Kaminari pagination: ❌ Error (#{e.message})"
      end
    else
      puts "  Kaminari pagination: ⚠️  Not available"
    end
  end

  def provide_recommendations(diagnostic_info)
    if diagnostic_info[:fully_operational]
      puts "✅ Pagination system is working correctly"
      puts "  No action required"
    elsif diagnostic_info[:kaminari_available] && !diagnostic_info[:fully_operational]
      puts "⚠️  Kaminari is available but not fully integrated"
      puts "  Recommendations:"
      puts "  - Check Kaminari initializers"
      puts "  - Verify gem loading order"
      puts "  - Restart the application"
    else
      puts "❌ Kaminari is not available"
      puts "  Recommendations:"
      puts "  - Add 'gem \"kaminari\"' to your Gemfile"
      puts "  - Run 'bundle install'"
      puts "  - Restart the application"
      puts "  - SafePagination fallback will be used automatically"
    end
    
    if diagnostic_info[:errors].any?
      puts
      puts "🔧 Troubleshooting:"
      puts "  - Check application logs for detailed error messages"
      puts "  - Verify all gems are properly installed"
      puts "  - Ensure database connectivity"
      puts "  - Run 'rake pagination:diagnose' for detailed information"
    end
  end
end