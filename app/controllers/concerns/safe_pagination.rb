# frozen_string_literal: true

# SafePagination provides resilient pagination that gracefully degrades
# when Kaminari is not available, preventing NoMethodError exceptions
module SafePagination
  extend ActiveSupport::Concern

  # Safely paginate an ActiveRecord relation with fallback support
  # 
  # @param relation [ActiveRecord::Relation] The relation to paginate
  # @param page [String, Integer, nil] The page number (defaults to 1)
  # @param per_page [Integer] Number of records per page (defaults to 20)
  # @return [ActiveRecord::Relation] Paginated relation with metadata methods
  def safe_paginate(relation, page: nil, per_page: 20)
    page_num = normalize_page_number(page)
    per_page = normalize_per_page(per_page)

    if kaminari_available?(relation)
      use_kaminari_pagination(relation, page_num, per_page)
    else
      use_fallback_pagination(relation, page_num, per_page)
    end
  end

  private

  # Check if Kaminari is available and the relation supports pagination
  def kaminari_available?(relation)
    defined?(Kaminari) && relation.respond_to?(:page)
  end

  # Use Kaminari for pagination (optimal path)
  def use_kaminari_pagination(relation, page, per_page)
    Rails.logger.debug "Using Kaminari pagination (page: #{page}, per_page: #{per_page})"
    relation.page(page).per(per_page)
  end

  # Use fallback pagination with LIMIT/OFFSET
  def use_fallback_pagination(relation, page, per_page)
    log_fallback_usage(page, per_page)
    
    offset = (page - 1) * per_page
    limited_relation = relation.limit(per_page).offset([offset, 0].max)
    
    add_pagination_metadata(limited_relation, relation, page, per_page)
  end

  # Add pagination metadata methods to the relation
  def add_pagination_metadata(limited_relation, original_relation, page, per_page)
    # Cache the total count to avoid multiple queries
    total_count = original_relation.count
    total_pages = (total_count.to_f / per_page).ceil
    
    # Add pagination methods to the relation instance
    limited_relation.define_singleton_method(:current_page) { page }
    limited_relation.define_singleton_method(:total_pages) { total_pages }
    limited_relation.define_singleton_method(:total_count) { total_count }
    limited_relation.define_singleton_method(:limit_value) { per_page }
    limited_relation.define_singleton_method(:total_entries) { total_count } # Alias for compatibility
    
    # Add navigation helper methods
    limited_relation.define_singleton_method(:next_page) do
      page < total_pages ? page + 1 : nil
    end
    
    limited_relation.define_singleton_method(:prev_page) do
      page > 1 ? page - 1 : nil
    end
    
    limited_relation.define_singleton_method(:first_page?) { page == 1 }
    limited_relation.define_singleton_method(:last_page?) { page >= total_pages }
    
    # Add range information
    limited_relation.define_singleton_method(:offset_value) { (page - 1) * per_page }
    limited_relation.define_singleton_method(:size) { limited_relation.to_a.size }
    
    limited_relation
  end

  # Normalize page number to ensure it's a positive integer
  def normalize_page_number(page)
    page_num = page.to_i
    page_num > 0 ? page_num : 1
  end

  # Normalize per_page to ensure it's within reasonable bounds
  def normalize_per_page(per_page)
    per_page = per_page.to_i
    
    # Ensure per_page is between 1 and 100 for performance
    case per_page
    when 0..1
      20 # Default
    when 2..100
      per_page
    else
      100 # Maximum
    end
  end

  # Log when fallback pagination is used for monitoring
  def log_fallback_usage(page, per_page)
    Rails.logger.warn "⚠️  Using fallback pagination - Kaminari not available (page: #{page}, per_page: #{per_page})"
    
    # Send to error tracking if available
    if defined?(Sentry)
      Sentry.capture_message(
        "Pagination fallback used",
        level: :warning,
        extra: {
          page: page,
          per_page: per_page,
          controller: self.class.name,
          action: action_name,
          kaminari_defined: defined?(Kaminari),
          timestamp: Time.current
        }
      )
    end
    
    # Increment metrics if available
    if defined?(StatsD)
      StatsD.increment('pagination.fallback_used')
    end
  end
end