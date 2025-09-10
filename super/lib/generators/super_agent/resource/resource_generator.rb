# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module SuperAgent
  module Generators
    class ResourceGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      desc "Generate a SuperAgent resource (workflow + agent or simple agent)"

      argument :actions, type: :array, default: [], banner: "action action"
      class_option :simple, type: :boolean, default: false, desc: "Generate simple ActiveAgent-style agent without workflow"

      def create_workflow
        return if options[:simple]
        template "workflow.rb", "app/workflows/#{file_name}_workflow.rb"
      end

      def create_agent
        if options[:simple]
          template "simple_agent.rb", "app/agents/#{file_name}_agent.rb"
        else
          template "agent.rb", "app/agents/#{file_name}_agent.rb"
        end
      end

      def create_test_files
        if defined?(RSpec)
          unless options[:simple]
            template "workflow_spec.rb", "spec/workflows/#{file_name}_workflow_spec.rb"
          end
          
          if options[:simple]
            template "agent_simple_spec.rb", "spec/agents/#{file_name}_agent_spec.rb"
          else
            template "agent_spec.rb", "spec/agents/#{file_name}_agent_spec.rb"
          end
        else
          unless options[:simple]
            template "workflow_test.rb", "test/workflows/#{file_name}_workflow_test.rb"
          end
          
          if options[:simple]
            template "agent_simple_test.rb", "test/agents/#{file_name}_agent_test.rb"
          else
            template "agent_test.rb", "test/agents/#{file_name}_agent_test.rb"
          end
        end
      end

      private

      def actions_list
        actions.empty? ? %w[index show create update destroy] : actions
      end

      def class_name
        name.classify
      end
    end
  end
end