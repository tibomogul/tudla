# frozen_string_literal: true

class ReportAiAssistService
  class Error < StandardError; end

  MAX_HISTORY_MESSAGES = 50
  ALLOWED_ROLES = %w[user assistant].freeze

  def initialize(user:, organization:)
    @user = user
    @organization = organization
  end

  def call(content:, message:, conversation_history: [])
    history = sanitize_history(conversation_history)
    assistant = build_assistant

    # Send content as a separate user message to avoid prompt injection
    if content.present?
      assistant.add_message(role: "user", content: "Here is my current report content:\n\n#{content}")
      assistant.add_message(role: "assistant", content: "Got it. I've noted your current report content. How can I help?")
    end

    history.each do |msg|
      assistant.add_message(role: msg["role"], content: msg["content"])
    end

    messages = assistant.add_message_and_run!(content: message)

    last_assistant_msg = messages.reverse.find { |m| m.role == "assistant" }
    reply = last_assistant_msg&.content || "Sorry, I couldn't generate a response."

    updated_content = extract_fence_content(reply)
    if updated_content
      # strip all fenced content
      reply = reply.gsub(/~~~report_content\s*\n.*?\n\s*~~~/m, "").strip
      reply = "I've updated the report content." if reply.blank?
    end

    { reply: reply, updated_content: updated_content }
  rescue RuntimeError, Faraday::Error => e
    Rails.logger.error("[ReportAiAssistService] #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
    raise Error, "Sorry, something went wrong while processing your request."
  end

  private

  def sanitize_history(history)
    Array(history)
      .select { |msg| msg.respond_to?(:[]) && ALLOWED_ROLES.include?(msg["role"]) && msg["content"].present? }
      .last(MAX_HISTORY_MESSAGES)
  end

  def build_llm
    raise Error, "LLM is not configured for this organization." unless @organization&.llm_configured?

    Langchain::LLM::OpenAI.new(
      api_key: @organization.llm_api_key,
      default_options: {
        chat_model: @organization.llm_model,
        uri_base: @organization.llm_api_base
      }
    )
  end

  def build_assistant
    Langchain::Assistant.new(
      llm: build_llm,
      tools: [ McpToolAdapter.new(user: @user) ],
      instructions: build_instructions
    )
  end

  def build_instructions
    <<~PROMPT
      You are a helpful writing assistant for project reports. You help users draft and improve their report content.

      The user will provide their current report content in the first message.

      When you draft or modify the report content, wrap the FULL draft/updated content in a ~~~report_content fence block like this:

      ~~~report_content
      (full draft/updated report content here)
      ~~~

      Only include the fence block when you are providing draft/modified content. If you are just answering a question or discussing without drafting or changing the content, do not include the fence block.

      You have access to MCP tools that can query project and task data. Use them when the user asks about project status, tasks, or other data that would help write the report.
    PROMPT
  end

  # Extracts the content from the last ~~~report_content fence block.
  # The greedy .* prefix ensures we match the final block when the LLM
  # emits multiple revisions — only the last one matters.
  def extract_fence_content(reply)
    match = reply.match(/.*~~~report_content\s*\n(.*?)\n\s*~~~/m)
    match&.[](1)
  end
end
