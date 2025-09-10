# frozen_string_literal: true

module SuperAgent
  module Workflow
    module Tasks
      # Task for sending Turbo Stream updates to the UI
      class TurboStreamTask < Task
        def initialize(name, config = {})
          super(name, config)
          @target = config[:target]
          @action = config[:action] || :replace
          @template = config[:template]
          @partial = config[:partial]
          @locals = config[:locals] || {}
          @content = config[:content]
        end

        def execute(context)
          unless defined?(Turbo::Streams::ActionBroadcastJob)
            raise "Turbo is not available. Please add `gem 'turbo-rails'` to your Gemfile."
          end

          target_selector = interpolate_template(@target, context)
          content_data = interpolate_content(context)

          case @action.to_sym
          when :replace
            turbo_stream.replace(target_selector, content_data)
          when :update
            turbo_stream.update(target_selector, content_data)
          when :append
            turbo_stream.append(target_selector, content_data)
          when :prepend
            turbo_stream.prepend(target_selector, content_data)
          when :remove
            turbo_stream.remove(target_selector)
          else
            raise ArgumentError, "Unknown Turbo Stream action: #{@action}"
          end

          { action: @action, target: target_selector, content: content_data }
        end

        def self.name
          :turbo_stream
        end

        private

        def turbo_stream
          Turbo::Streams::TagBuilder.new
        end

        def interpolate_template(template, context)
          return template unless template.is_a?(String) && template.include?('{{')

          template.gsub(/\{\{(\w+)\}\}/) do |match|
            key = match[2..-3] # Remove {{ and }}
            context.get(key.to_sym) || match
          end
        end

        def interpolate_content(context)
          if @content
            interpolate_template(@content, context)
          elsif @template
            interpolate_template(@template, context)
          elsif @partial
            render_partial(context)
          else
            raise ArgumentError, "Must provide :content, :template, or :partial"
          end
        end

        def render_partial(context)
          return @partial unless @partial.is_a?(String)

          # For now, return the interpolated partial name
          # In a real Rails app, this would use ActionView
          interpolate_template(@partial, context)
        end
      end
    end
  end
end