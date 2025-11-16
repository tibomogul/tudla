# frozen_string_literal: true

# Langchain / LLM configuration
#
# Uses an OpenAI-compatible chat API configured via environment variables:
# - LLM_API_KEY   (required)
# - LLM_API_BASE  (optional, e.g. https://api.openai.com or other compatible endpoint)
# - LLM_MODEL     (optional, defaults to gpt-4o-mini)

require "langchain"
require "openai"

LLM_CLIENT = if ENV["LLM_API_KEY"].present?
  # ruby-openai already prefixes `/v1`, so if LLM_API_BASE includes
  # `/v1` we strip it to avoid `/v1/v1/...` URLs.
  raw_base = ENV["LLM_API_BASE"].presence
  normalized_base = if raw_base&.end_with?("/v1")
    raw_base.sub(%r{/v1$}, "")
  else
    raw_base
  end

  Langchain::LLM::OpenAI.new(
    api_key: ENV["LLM_API_KEY"],
    llm_options: {
      uri_base: normalized_base
    }.compact,
    default_options: {
      chat_model: ENV["LLM_MODEL"].presence || "gpt-4o-mini"
    }
  )
else
  Rails.logger.warn("LLM_API_KEY is not set; AI draft generation will be disabled")
  nil
end
