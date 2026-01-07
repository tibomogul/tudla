ActionMailer::Base.smtp_settings = if ENV["ACTION_MAILER_ADDRESS"]
  {
    address: ENV.fetch("ACTION_MAILER_ADDRESS") { "127.0.0.1" },
    port: ENV.fetch("ACTION_MAILER_PORT") { 1025 },
    user_name: ENV["ACTION_MAILER_USERNAME"],
    password: ENV["ACTION_MAILER_PASSWORD"],
    authentication: "plain",
    enable_starttls: true
  }
else
  {
    address: "127.0.0.1",
    port: 1025
  }
end
