# frozen_string_literal: true

require "rails/generators"

module SuperAgent
  module Generators
    class AgentGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      desc "Generate a SuperAgent agent"
      class_option :simple, type: :boolean, default: false, desc: "Generate simple ActiveAgent-style agent"

      def create_agent
        if options[:simple]
          template "simple_agent.rb", "app/agents/#{file_name}_agent.rb"
        else
          template "agent.rb", "app/agents/#{file_name}_agent.rb"
        end
      end

      def create_test_file
        if defined?(RSpec)
          if options[:simple]
            template "agent_simple_spec.rb", "spec/agents/#{file_name}_agent_spec.rb"
          else
            template "agent_spec.rb", "spec/agents/#{file_name}_agent_spec.rb"
          end
        else
          if options[:simple]
            template "agent_simple_test.rb", "test/agents/#{file_name}_agent_test.rb"
          else
            template "agent_test.rb", "test/agents/#{file_name}_agent_test.rb"
          end
        end
      end

      private

      def class_name
        name.classify
      end
    end
  end
end