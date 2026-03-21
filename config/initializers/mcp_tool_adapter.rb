# frozen_string_literal: true

Rails.application.config.to_prepare do
  Rails.autoloaders.main.eager_load_dir(Rails.root.join("app/tools"))
  McpToolAdapter.register_mcp_tools!
end
