# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: 'noreply@agentform.com'
  layout 'mailer'
end