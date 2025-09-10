# frozen_string_literal: true

module Cacheable
  extend ActiveSupport::Concern

  included do
    after_commit :bust_cache
  end

  class_methods do
    def cached_find(id, expires_in: 1.hour)
      Rails.cache.fetch("#{name.downcase}/#{id}", expires_in: expires_in) do
        find(id)
      end
    end

    def cached_count(scope_name = nil, expires_in: 5.minutes)
      cache_key = scope_name ? "#{name.downcase}/#{scope_name}/count" : "#{name.downcase}/count"
      Rails.cache.fetch(cache_key, expires_in: expires_in) do
        scope_name ? public_send(scope_name).count : count
      end
    end
  end

  # Instance methods
  def cache_key_with_version
    "#{model_name.cache_key}/#{id}-#{updated_at.to_i}"
  end

  private

  def bust_cache
    Rails.cache.delete_matched("#{self.class.name.downcase}/*")
  end
end