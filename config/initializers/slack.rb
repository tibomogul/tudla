# Slack configuration for slack-ruby-client
# Note: Most configuration is done per-client instance
# This initializer can be used for global defaults if needed

Slack::Web::Client.configure do |config|
  # Optional: Configure logging
  # config.logger = Rails.logger
  # config.logger.level = Logger::INFO
end
