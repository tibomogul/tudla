# frozen_string_literal: true

Rails.application.config.to_prepare do
  Dir[Rails.root.join("app/tools/**/*_tool.rb")].each { |f| require_dependency f }
  McpToolAdapter.register_mcp_tools!
end
