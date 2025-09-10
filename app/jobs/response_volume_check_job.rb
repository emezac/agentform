class ResponseVolumeCheckJob < ApplicationJob
  queue_as :default

  HIGH_VOLUME_THRESHOLD = 100 # responses per day

  def perform
    check_high_volume_forms
  end

  private

  def check_high_volume_forms
    # Find forms with high response volume today
    high_volume_forms = Form.joins(:form_responses)
                           .where(form_responses: { created_at: Date.current.beginning_of_day..Date.current.end_of_day })
                           .group('forms.id')
                           .having('COUNT(form_responses.id) >= ?', HIGH_VOLUME_THRESHOLD)
                           .includes(:user)

    high_volume_forms.find_each do |form|
      response_count = form.form_responses
                          .where(created_at: Date.current.beginning_of_day..Date.current.end_of_day)
                          .count

      # Only notify once per day per form
      existing_notification = AdminNotification.where(
        event_type: 'high_response_volume',
        metadata: { form_id: form.id },
        created_at: Date.current.beginning_of_day..Date.current.end_of_day
      ).exists?

      unless existing_notification
        AdminNotificationService.notify(:high_response_volume,
          user: form.user,
          form: form,
          response_count: response_count
        )
      end
    end
  end
end