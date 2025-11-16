# frozen_string_literal: true

module McpToolsDefinition
  extend Langchain::ToolDefinition

  def self.register_mcp_tools!
    return unless defined?(ApplicationTool)

    ApplicationTool.descendants.each do |tool_class|
      next unless tool_class.name&.end_with?("Tool")

      function_name = tool_class.name.sub(/Tool\z/, "").underscore

      define_function function_name do
        description(tool_class.try(:description) || "MCP tool #{tool_class.name}")

        parameters do
          property :arguments,
                   type: "object",
                   description: "Arguments hash passed through to #{tool_class.name}#call",
                   required: false
        end
      end

      define_singleton_method(function_name) do |arguments: {}|
        args = arguments.respond_to?(:to_h) ? arguments.to_h : {}
        tool_class.new.call(**args.symbolize_keys)
      end
    end
  end
end

McpToolsDefinition.register_mcp_tools!
