# frozen_string_literal: true

module SuperAgent
  module A2A
    # Thread-safe cache manager for A2A operations
    class CacheManager
      def initialize(ttl: 300)
        @ttl = ttl
        @cache = {}
        @mutex = Mutex.new
      end

      def get(key)
        @mutex.synchronize do
          entry = @cache[key]
          return nil unless entry
          return nil if expired?(entry)

          entry[:value]
        end
      end

      def set(key, value)
        @mutex.synchronize do
          @cache[key] = {
            value: value,
            expires_at: Time.current + @ttl,
          }
        end
      end

      def cached?(key)
        @mutex.synchronize do
          entry = @cache[key]
          entry && !expired?(entry)
        end
      end

      def clear
        @mutex.synchronize do
          @cache.clear
        end
      end

      def cleanup_expired
        @mutex.synchronize do
          @cache.reject! { |_, entry| expired?(entry) }
        end
      end

      def size
        @mutex.synchronize do
          @cache.size
        end
      end

      def keys
        @mutex.synchronize do
          @cache.keys
        end
      end

      private

      def expired?(entry)
        Time.current > entry[:expires_at]
      end
    end
  end
end
