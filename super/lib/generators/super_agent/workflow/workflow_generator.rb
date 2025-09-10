# frozen_string_literal: true

require "rails/generators"

module SuperAgent
  module Generators
    class WorkflowGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      desc "Generate a SuperAgent workflow"

      def create_workflow
        template "workflow.rb", "app/workflows/#{file_name}_workflow.rb"
      end

      def create_test_file
        if defined?(RSpec)
          template "workflow_spec.rb", "spec/workflows/#{file_name}_workflow_spec.rb"
        else
          template "workflow_test.rb", "test/workflows/#{file_name}_workflow_test.rb"
        end
      end

      private

      def class_name
        name.classify
      end
    end
  end
end