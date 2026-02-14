# frozen_string_literal: true

# Handles MCP (Model Context Protocol) requests via Streamable HTTP transport.
# Clients POST JSON-RPC messages and receive JSON-RPC responses in the HTTP body.
class McpController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :custom_authenticate_user!

  before_action :authenticate_mcp_token!, except: []

  def handle
    body = request.body.read
    server = build_mcp_server
    result = server.handle_json(body)

    # JSON-RPC notifications (no "id") return nil from handle_json.
    # Per Streamable HTTP spec, respond with 202 Accepted and no body.
    if result.nil?
      head :accepted
    else
      render json: result
    end
  end

  private

  # Build a new MCP::Server per request with the authenticated user in server_context
  def build_mcp_server
    MCP::Server.new(
      name: "tudla",
      version: "1.0.0",
      tools: tool_classes,
      server_context: { user: @mcp_user }
    )
  end

  # Return all ApplicationTool subclasses. In production, classes are eager-loaded
  # so descendants are already populated. In development, we require_dependency
  # each file to populate descendants since Rails lazy-loads.
  def tool_classes
    if Rails.application.config.eager_load
      ApplicationTool.descendants
    else
      Dir[Rails.root.join("app/tools/*_tool.rb")].each { |f| require_dependency f }
      ApplicationTool.descendants
    end
  end

  # Authenticate via Bearer token. Allow unauthenticated requests for handshake
  # methods (initialize, ping, tools/list) — tools/call will fail in the tool
  # itself if server_context[:user] is nil.
  def authenticate_mcp_token!
    auth_header = request.headers["Authorization"]
    if auth_header&.start_with?("Bearer ")
      token = auth_header.sub("Bearer ", "")
      @mcp_user = ApiToken.authenticate(token)
      Rails.logger.info "MCP Auth: User #{@mcp_user&.id || 'nil'} (token #{@mcp_user ? 'valid' : 'invalid'})"
    else
      @mcp_user = nil
      Rails.logger.info "MCP Auth: No Bearer token provided"
    end
  end
end
