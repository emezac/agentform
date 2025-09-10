require 'rufus-scheduler'

module SuperAgent
  module Workflow
    module Tasks
      # Task for scheduling recurring workflows using cron expressions
      #
      # @example Usage in workflow
      #   step :schedule_report, uses: :cron, with: {
      #     schedule: "0 9 * * *",
      #     workflow_class: "DailyReportWorkflow",
      #     initial_input: { report_type: "sales" }
      #   }
      #
      class CronTask < Task
        def initialize(name, config = {})
          super(name, config)
          @schedule = config[:schedule]
          @workflow_class_name = config[:workflow_class]
          @initial_input_key = config[:initial_input] || :initial_input
          @job_id_key = config[:as] || :job_id
        end

        def execute(context)
          schedule = resolve_schedule(context.get(:schedule) || @schedule)
          workflow_class_name = resolve_workflow_class(context.get(:workflow_class) || @workflow_class_name)
          initial_input = resolve_initial_input(context.get(@initial_input_key))

          raise ArgumentError, "Schedule is required" unless schedule
          raise ArgumentError, "Workflow class is required" unless workflow_class_name

          job_id = schedule_workflow(schedule, workflow_class_name, initial_input)

          {
            @job_id_key => job_id,
            schedule: schedule,
            workflow_class: workflow_class_name,
            scheduled_at: Time.now,
            status: "scheduled"
          }
        end

        private

        def resolve_schedule(schedule_param)
          case schedule_param
          when String
            schedule_param
          when Hash
            schedule_param[:schedule] || schedule_param[:cron]
          else
            schedule_param.to_s
          end
        end

        def resolve_workflow_class(class_param)
          case class_param
          when String
            class_param
          when Class
            class_param.name
          else
            class_param.to_s
          end
        end

        def resolve_initial_input(input_param)
          case input_param
          when Hash
            input_param
          when Symbol
            { input_param => true }
          else
            {}
          end
        end

        def schedule_workflow(schedule, workflow_class_name, initial_input)
          scheduler = Rufus::Scheduler.new
          
          job = scheduler.cron schedule do
            SuperAgent::WorkflowJob.perform_later(
              workflow_class_name,
              initial_input
            )
          end

          # Return job ID for management
          job.id
        end

        def self.name
          :cron
        end
      end
    end
  end
end