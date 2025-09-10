# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SuperAgent::WorkflowDefinition do
  describe 'new workflow DSL' do
    let(:test_workflow) do
      Class.new(described_class) do
        workflow do
          timeout 30
          retry_policy max_retries: 2, delay: 1
          
          task :first_step do
            input :data
            output :processed
            description "Process input data"
            
            process { |data| data * 2 }
          end

          llm :second_step, "Process: {{processed}}" do
            model "gpt-4"
            temperature 0.5
            run_if { |ctx| ctx.get(:processed) == 20 }  # Use run_if instead of run_when
          end

          task :third_step do
            run_if { |ctx| ctx.get(:processed) > 10 }
            process { |ctx| { valid: ctx.get(:processed) > 15 } }
          end
        end
      end
    end

    it 'creates steps with new syntax' do
      steps = test_workflow.all_steps
      expect(steps.size).to eq(3)
      
      first = steps[0]
      expect(first[:name]).to eq(:first_step)
      expect(first[:config][:uses]).to eq(:direct_handler)
      expect(first[:config][:inputs]).to eq([:data])
      expect(first[:config][:outputs]).to eq([:processed])
      expect(first[:config][:meta][:description]).to eq("Process input data")
    end

    it 'configures LLM tasks with shorthand' do
      steps = test_workflow.all_steps
      second = steps[1]
      
      expect(second[:name]).to eq(:second_step)
      expect(second[:config][:uses]).to eq(:llm)
      expect(second[:config][:prompt]).to eq("Process: {{processed}}")
      expect(second[:config][:model]).to eq("gpt-4")
      expect(second[:config][:temperature]).to eq(0.5)
    end

    it 'handles conditional execution' do
      steps = test_workflow.all_steps
      third = steps[2]
      
      expect(third[:config]).to have_key(:if)
      
      context = SuperAgent::Workflow::Context.new(processed: 15)
      condition = third[:config][:if]
      expect(condition.call(context)).to be true
      
      context2 = SuperAgent::Workflow::Context.new(processed: 5)
      expect(condition.call(context2)).to be false
    end

    it 'stores workflow configuration' do
      config = test_workflow.new.workflow_config
      
      expect(config[:timeout]).to eq(30)
      expect(config[:retry_policy][:max_retries]).to eq(2)
      expect(config[:retry_policy][:delay]).to eq(1)
    end
  end

  describe 'TaskConfigurator' do
    let(:configurator) { described_class::TaskConfigurator.new(:test, :direct_handler) }

    it 'builds configuration correctly' do
      configurator
        .input(:data1, :data2)
        .output(:result)
        .model("gpt-4")
        .temperature(0.7)
        .description("Test task")
        .tags(:important, :api)
        .run_if { |ctx| ctx.get(:data1).present? }

      config = configurator.build
      
      expect(config[:name]).to eq(:test)
      expect(config[:config][:inputs]).to eq([:data1, :data2])
      expect(config[:config][:outputs]).to eq([:result])
      expect(config[:config][:model]).to eq("gpt-4")
      expect(config[:config][:temperature]).to eq(0.7)
      expect(config[:config][:meta][:description]).to eq("Test task")
      expect(config[:config][:meta][:tags]).to eq([:important, :api])
      expect(config[:config]).to have_key(:if)
    end

    it 'wraps handlers correctly' do
      configurator
        .input(:value)
        .handler { |value| value * 2 }
      
      config = configurator.build
      handler = config[:config][:with][:handler]
      expect(handler).to respond_to(:call)
      
      context = SuperAgent::Workflow::Context.new(value: 5)
      result = handler.call(context)
      expect(result).to eq(10)
    end

    it 'handles input extraction in wrapped handlers' do
      configurator
        .input(:value1, :value2)
        .handler { |v1, v2, _ctx| v1 + v2 }
      
      config = configurator.build
      handler = config[:config][:with][:handler]
      
      context = SuperAgent::Workflow::Context.new(value1: 10, value2: 20)
      result = handler.call(context)
      expect(result).to eq(30)
    end

    it 'handles output mapping' do
      configurator
        .output(:final_result)
        .handler { |_ctx| { computed: 42 } }
      
      config = configurator.build
      handler = config[:config][:with][:handler]
      
      context = SuperAgent::Workflow::Context.new
      result = handler.call(context)
      expect(result).to eq({ final_result: { computed: 42 } })
    end

    it 'supports conditional execution shortcuts' do
      configurator
        .run_when(:trigger, true)
        .skip_when(:disabled, true)
      
      config = configurator.build
      condition = config[:config][:if]
      
      # Should run when trigger=true and disabled!=true
      context1 = SuperAgent::Workflow::Context.new(trigger: true, disabled: false)
      expect(condition.call(context1)).to be true
      
      # Should not run when disabled=true
      context2 = SuperAgent::Workflow::Context.new(trigger: true, disabled: true)
      expect(condition.call(context2)).to be false
    end

    it 'captures unknown methods as configuration' do
      configurator.custom_option("custom_value")
      
      config = configurator.build
      expect(config[:config][:custom_option]).to eq("custom_value")
    end
  end

  describe 'workflow shortcuts' do
    let(:shortcut_workflow) do
      Class.new(described_class) do
        workflow do
          llm :chat_task, "Hello {{name}}" do
            model "gpt-3.5-turbo"
            temperature 0.8
          end

          validate :check_input do
            process { |ctx| ctx.get(:name).present? }
          end

          fetch :get_user, "User" do
            find_by id: "{{user_id}}"
          end

          email :send_welcome, "UserMailer", "welcome" do
            params user: "{{user}}"
          end

          image :generate_avatar, "A professional avatar for {{name}}" do
            size "512x512"
            quality "hd"
          end

          search :find_info, "{{query}}" do
            search_context_size "high"
          end
        end
      end
    end

    it 'creates LLM tasks correctly' do
      steps = shortcut_workflow.all_steps
      llm_step = steps.find { |s| s[:name] == :chat_task }
      
      expect(llm_step[:config][:uses]).to eq(:llm)
      expect(llm_step[:config][:prompt]).to eq("Hello {{name}}")
      expect(llm_step[:config][:model]).to eq("gpt-3.5-turbo")
      expect(llm_step[:config][:temperature]).to eq(0.8)
    end

    it 'creates validation tasks' do
      steps = shortcut_workflow.all_steps
      validate_step = steps.find { |s| s[:name] == :check_input }
      
      expect(validate_step[:config][:uses]).to eq(:direct_handler)
      expect(validate_step[:config][:meta][:validation]).to be true
    end

    it 'creates database fetch tasks' do
      steps = shortcut_workflow.all_steps
      fetch_step = steps.find { |s| s[:name] == :get_user }
      
      expect(fetch_step[:config][:uses]).to eq(:active_record_find)
      expect(fetch_step[:config][:model]).to eq("User")
    end

    it 'creates email tasks' do
      steps = shortcut_workflow.all_steps
      email_step = steps.find { |s| s[:name] == :send_welcome }
      
      expect(email_step[:config][:uses]).to eq(:action_mailer)
      expect(email_step[:config][:mailer]).to eq("UserMailer")
      expect(email_step[:config][:action]).to eq("welcome")
    end

    it 'creates image generation tasks' do
      steps = shortcut_workflow.all_steps
      image_step = steps.find { |s| s[:name] == :generate_avatar }
      
      expect(image_step[:config][:uses]).to eq(:image_generation)
      expect(image_step[:config][:prompt]).to eq("A professional avatar for {{name}}")
      expect(image_step[:config][:size]).to eq("512x512")
    end

    it 'creates web search tasks' do
      steps = shortcut_workflow.all_steps
      search_step = steps.find { |s| s[:name] == :find_info }
      
      expect(search_step[:config][:uses]).to eq(:web_search)
      expect(search_step[:config][:query]).to eq("{{query}}")
    end
  end

  describe 'workflow hooks and error handling' do
    let(:hook_workflow) do
      Class.new(described_class) do
        workflow do
          before_all { |ctx| ctx.set(:before_ran, true) }
          after_all { |ctx| ctx.set(:after_ran, true) }
          
          on_error :failing_step do |error, context|
            { recovered: true, error: error.message }
          end
          
          on_error do |error, context|  # Global error handler
            { global_fallback: true }
          end
          
          task :normal_step do
            process { "success" }
          end
          
          task :failing_step do
            process { raise "Intentional error" }
          end
        end
      end
    end

    it 'stores hooks correctly' do
      config = hook_workflow.new.workflow_config
      
      expect(config[:before_hooks]).to be_an(Array)
      expect(config[:before_hooks].size).to eq(1)
      
      expect(config[:after_hooks]).to be_an(Array)
      expect(config[:after_hooks].size).to eq(1)
      
      expect(config[:error_handlers]).to have_key(:failing_step)
      expect(config[:error_handlers]).to have_key(:global)
    end
  end

  describe 'backward compatibility' do
    let(:old_syntax_workflow) do
      Class.new(described_class) do
        steps do
          step :old_step, uses: :direct_handler, with: {
            handler: ->(ctx) { "old syntax" }
          }
        end
      end
    end

    around do |example|
      # Temporarily disable deprecation warnings for this test
      original = SuperAgent.configuration.deprecation_warnings
      SuperAgent.configuration.deprecation_warnings = false
      
      example.run
      
      SuperAgent.configuration.deprecation_warnings = original
    end

    it 'still works with old syntax' do
      expect { old_syntax_workflow.all_steps }.not_to raise_error
      
      steps = old_syntax_workflow.all_steps
      expect(steps.size).to eq(1)
      expect(steps[0][:name]).to eq(:old_step)
    end
  end
end
