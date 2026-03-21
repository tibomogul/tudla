# frozen_string_literal: true

class McpToolAdapter
  extend Langchain::ToolDefinition

  attr_reader :server_context

  def initialize(user:)
    @server_context = { user: user }
  end

  def self.register_mcp_tools!
    # Reset for development reload safety
    @function_schemas = nil

    ApplicationTool.descendants.each do |tool_class|
      register_tool(tool_class)
    end
  end

  def self.register_tool(tool_class)
    method_name = tool_method_name(tool_class)
    tool_description = tool_class.description_value || tool_class.name
    schema = tool_class.input_schema_value.to_h
    properties = schema[:properties] || {}
    required_list = (schema[:required] || []).map(&:to_s)

    if properties.any?
      define_function method_name, description: tool_description do
        properties.each do |prop_name, prop_schema|
          opts = {
            type: prop_schema[:type] || "string",
            description: prop_schema[:description] || "",
            required: required_list.include?(prop_name.to_s)
          }
          opts[:enum] = prop_schema[:enum] if prop_schema[:enum]
          property prop_name, **opts
        end
      end
    else
      define_function method_name, description: tool_description
    end

    define_method(method_name) do |**args|
      instance = tool_class.new(server_context)
      text = instance.execute(**args).to_s
      Langchain::ToolResponse.new(content: text)
    rescue Pundit::NotAuthorizedError => e
      Langchain::ToolResponse.new(content: "Authorization error: #{e.message}")
    rescue StandardError => e
      Rails.logger.error "LangChain tool error (#{tool_class.name}): #{e.message}"
      Langchain::ToolResponse.new(content: "Error: #{e.message}")
    end
  end

  def self.tool_method_name(tool_class)
    tool_class.name
      .gsub(/Tool$/, "")
      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
      .downcase
      .to_sym
  end
end
