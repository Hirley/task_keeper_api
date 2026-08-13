class ApplicationMailer < ActionMailer::Base
  default from: "no-reply@task-keeper.local"
  layout "mailer"
end
