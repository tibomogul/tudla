# frozen_string_literal: true

# Rack middleware for MCP API token authentication
class McpAuthMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    # Only intercept MCP requests
    return @app.call(env) unless mcp_request?(env)

    Rails.logger.info "MCP Auth Middleware: Intercepting MCP request"

    # Extract and validate token
    auth_header = env["HTTP_AUTHORIZATION"]
    unless auth_header
      Rails.logger.warn "MCP Auth: No Authorization header - REJECTED"
      return unauthorized_response
    end

    token = auth_header.sub(/^Bearer /, "")
    Rails.logger.info "MCP Auth: Token present, validating..."

    user = ApiToken.authenticate(token)
    
    if user
      # Store user in Thread.current for tools to access
      Thread.current[:mcp_current_user] = user
      Rails.logger.info "MCP Auth: User #{user.id} authenticated - ALLOWED"
      
      # Continue to fast-mcp
      @app.call(env)
    else
      Rails.logger.warn "MCP Auth: Invalid token - REJECTED"
      unauthorized_response
    end
  end

  private

  def mcp_request?(env)
    env["PATH_INFO"]&.start_with?("/mcp/")
  end

  def unauthorized_response
    [
      401,
      { "Content-Type" => "application/json" },
      [{ error: "Unauthorized", message: "Valid API token required" }.to_json]
    ]
  end
end
