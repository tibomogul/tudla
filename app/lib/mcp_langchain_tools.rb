# frozen_string_literal: true

# Protocol-based Langchainrb tools wrapper for the Task Manager MCP server.
#
# This module introspects the MCP server via the official JSON-RPC API
# (tools/list) to obtain tool definitions and JSON Schemas, then exposes
# them to Langchainrb using Langchain::ToolDefinition. Tool calls are
# dispatched back to the MCP server via tools/call.
#
# Environment variables:
# - MCP_MESSAGES_URL: Base URL for MCP messages endpoint
#     e.g. http://localhost:3000/mcp/messages
# - MCP_AUTH_TOKEN:   Optional Bearer token for Authorization header
#
# Usage (conceptual):
#   McpLangchainTools.load_from_mcp!
#   assistant = Langchain::Assistant.new(llm: LLM_CLIENT, tools: [McpLangchainTools])
#
module McpLangchainTools
  extend Langchain::ToolDefinition

  JSON_RPC_VERSION = "2.0"

  class << self
    # Fetch tool schemas from MCP server and register them as Langchain tools.
    def load_from_mcp!
      tools = fetch_tools_list
      register_from_mcp!(tools)
    rescue StandardError => e
      Rails.logger.error("McpLangchainTools.load_from_mcp! failed: #{e.class}: #{e.message}")
    end

    private

    def fetch_tools_list
      url = ENV["MCP_MESSAGES_URL"].presence || "http://localhost:3000/mcp/messages"
      uri = URI.parse(url)

      request_body = {
        jsonrpc: JSON_RPC_VERSION,
        id: "tools-list-#{SecureRandom.hex(4)}",
        method: "tools/list",
        params: {}
      }.to_json

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      if ENV["MCP_AUTH_TOKEN"].present?
        request["Authorization"] = "Bearer #{ENV["MCP_AUTH_TOKEN"]}"
      end
      request.body = request_body

      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        raise "MCP tools/list failed: HTTP #{response.code} #{response.message}"
      end

      data = JSON.parse(response.body)
      if data["error"]
        raise "MCP tools/list error: #{data["error"]["message"]}"
      end

      (data.dig("result", "tools") || []).map do |tool|
        {
          "name" => tool["name"],
          "description" => tool["description"],
          "inputSchema" => tool["inputSchema"] || {}
        }
      end
    end

    def register_from_mcp!(tools)
      tools.each do |tool|
        name = tool["name"]
        schema = tool["inputSchema"] || {}
        description = tool["description"] || "MCP tool #{name}"

        define_function name do
          description(description)

          parameters do
            build_parameters_from_schema(schema)
          end
        end

        define_singleton_method(name) do |**kwargs|
          call_tool_via_mcp(name, kwargs)
        end
      end
    end

    # Translate a JSON Schema object into Langchain ParameterBuilder calls.
    def build_parameters_from_schema(schema)
      properties = schema["properties"] || {}
      required = Array(schema["required"])

      if properties.empty?
        # No detailed schema, expose generic arguments hash.
        property :arguments,
                 type: "object",
                 description: "Arguments hash passed directly to MCP tool",
                 required: false
        return
      end

      properties.each do |param_name, prop|
        type = prop["type"] || "string"
        desc = prop["description"]
        enum_values = prop["enum"]
        required_flag = required.include?(param_name)

        options = {
          type: type,
          description: desc,
          required: required_flag
        }
        options[:enum] = enum_values if enum_values

        property param_name.to_sym, **options
      end
    end

    # Perform a tools/call request to the MCP server for a given tool name
    # and arguments hash.
    def call_tool_via_mcp(tool_name, arguments)
      url = ENV["MCP_MESSAGES_URL"].presence || "http://localhost:3000/mcp/messages"
      uri = URI.parse(url)

      request_body = {
        jsonrpc: JSON_RPC_VERSION,
        id: "tools-call-#{tool_name}-#{SecureRandom.hex(4)}",
        method: "tools/call",
        params: {
          toolName: tool_name,
          arguments: arguments
        }
      }.to_json

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      if ENV["MCP_AUTH_TOKEN"].present?
        request["Authorization"] = "Bearer #{ENV["MCP_AUTH_TOKEN"]}"
      end
      request.body = request_body

      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        raise "MCP tools/call failed for #{tool_name}: HTTP #{response.code} #{response.message}"
      end

      data = JSON.parse(response.body)
      if data["error"]
        raise "MCP tools/call error for #{tool_name}: #{data["error"]["message"]}"
      end

      # Generic handling: if the result has MCP content blocks, return a
      # concatenated string of text parts; otherwise return the raw result.
      result = data["result"]
      content = result && result["content"]
      if content.is_a?(Array)
        texts = content.filter_map { |c| c["text"] if c["type"] == "text" }
        return texts.join("\n") unless texts.empty?
      end

      result
    end
  end
end

# Auto-load tools at startup if desired. You can also call this manually
# from wherever you configure your Langchain assistants.
McpLangchainTools.load_from_mcp!
