class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("ACTION_MAILER_DEFAULT_FROM", "from@example.com")
  layout "mailer"
end
