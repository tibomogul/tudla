# Handles MCP discovery and OAuth metadata endpoints.
#
# This server uses pre-configured Bearer token authentication (API tokens
# managed in-app). OAuth authorization flow is NOT supported — discovery
# metadata is served so that MCP clients (e.g. rmcp/Kiro) can complete
# their probe sequence without erroring, but the authorize/token endpoints
# return explicit "unsupported" errors.
class McpDiscoveryController < ActionController::API
  # MCP discovery endpoint (/.well-known/mcp)
  def show
    metadata = {
      mcp_version: "1.0",
      server_name: Rails.application.class.module_parent_name.underscore.dasherize,
      server_version: "1.0.0",
      endpoints: {
        streamable_http: "#{base_url}/mcp"
      },
      capabilities: {
        tools: true,
        resources: false,
        prompts: false
      },
      authentication: {
        required: true,
        schemes: [ "bearer" ],
        instructions: "Provide a pre-configured API token via Authorization: Bearer <token>. " \
                       "OAuth is not supported. Generate tokens at #{base_url}/api_tokens."
      }
    }

    set_discovery_headers
    render json: metadata
  end

  # OAuth Protected Resource Metadata (RFC 9470)
  # /.well-known/oauth-protected-resource
  def prm
    metadata = {
      resource: "#{base_url}/mcp",
      bearer_methods_supported: [ "header" ]
    }

    set_discovery_headers
    render json: metadata
  end

  # OAuth Authorization Server Metadata (RFC 8414)
  # /.well-known/oauth-authorization-server
  #
  # Returned so rmcp probe succeeds (prevents "No authorization support
  # detected" error). The authorize/token endpoints reject all requests
  # with a clear message directing users to Bearer token auth.
  def oauth_metadata
    metadata = {
      issuer: base_url.to_s,
      authorization_endpoint: "#{base_url}/mcp/oauth/authorize",
      token_endpoint: "#{base_url}/mcp/oauth/token",
      response_types_supported: [],
      grant_types_supported: [],
      token_endpoint_auth_methods_supported: [ "none" ],
      scopes_supported: [ "mcp" ]
    }

    set_discovery_headers
    render json: metadata
  end

  # OAuth authorize — not supported, return a clear error.
  def oauth_authorize
    render json: {
      error: "unsupported_response_type",
      error_description: "This MCP server uses pre-configured Bearer token authentication. " \
                          "OAuth authorization flow is not supported. " \
                          "Configure your MCP client with an API token in the Authorization header."
    }, status: :bad_request
  end

  # OAuth token — not supported, return a clear error.
  def oauth_token
    render json: {
      error: "unsupported_grant_type",
      error_description: "This MCP server uses pre-configured Bearer token authentication. " \
                          "OAuth token exchange is not supported. " \
                          "Configure your MCP client with an API token in the Authorization header."
    }, status: :bad_request
  end

  private

  def base_url
    "#{request.scheme}://#{request.host_with_port}"
  end

  def set_discovery_headers
    response.set_header("X-Content-Type-Options", "nosniff")
    response.set_header("Cache-Control", "max-age=3600")
  end
end
