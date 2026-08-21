# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: 'no-reply@task-keeper.local'
  layout 'mailer'
end
