# frozen_string_literal: true

# Simple Rails mock for testing without full Rails environment
unless defined?(Rails)
  module Rails
    extend self
    
    def logger
      @logger ||= Logger.new($stdout, level: Logger::WARN)
    end
    
    def env
      ENV['RAILS_ENV'] || ENV['SUPER_AGENT_ENV'] || 'test'
    end

    def root
      Pathname.new(Dir.pwd)
    end

    def application
      @application ||= Application.new
    end

    class Application
      def config
        @config ||= Config.new
      end
    end

    class Config
      def to_prepare(&block)
        # In test environment, execute immediately
        block.call if block_given?
      end

      def after_initialize(&block)
        # In test environment, execute immediately  
        block.call if block_given?
      end
    end
  end
end

# Simple Time mock for consistent testing
unless defined?(Time.current)
  class Time
    def self.current
      now
    end
  end
end

# Simple ActiveRecord mock for testing
unless defined?(ActiveRecord)
  module ActiveRecord
    class Base
      def self.find(id)
        new.tap { |record| record.id = id }
      end

      def self.where(conditions)
        [new]
      end

      def self.create!(attributes)
        new.tap do |record|
          attributes.each { |k, v| record.send("#{k}=", v) if record.respond_to?("#{k}=") }
        end
      end

      attr_accessor :id, :name, :email

      def to_global_id
        double('GlobalID', to_s: "gid://test/#{self.class}/#{id}")
      end
    end

    class Migration
      def self.maintain_test_schema!
        # No-op for testing
      end
    end
  end
end

# Simple Pathname for Rails.root
unless defined?(Pathname)
  class Pathname
    def initialize(path)
      @path = path.to_s
    end

    def to_s
      @path
    end
  end
end
