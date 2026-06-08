# Example: PORO service object spec. Construct with keyword inputs, call the
# public method, assert the returned data. Stub external collaborators (LLM,
# HTTP, mailers) — never the system under test.
#
# WHY this shape: mirrors spec/services/report_ai_assist_service_spec.rb.

require "rails_helper"

RSpec.describe ReportAiAssistService do
  let(:user) { create(:user) }
  let(:organization) do
    create(:organization,
           llm_api_key: "sk-test",
           llm_api_base: "https://api.openai.com/v1",
           llm_model: "gpt-4o-mini")
  end
  let(:service) { described_class.new(user: user, organization: organization) }

  # WHY: stub the external LLM client so the spec exercises *our* parsing logic,
  # not the network. instance_double verifies against the real interface.
  let(:mock_llm)       { instance_double(Langchain::LLM::OpenAI) }
  let(:mock_assistant) { instance_double(Langchain::Assistant) }

  before do
    allow(Langchain::LLM::OpenAI).to receive(:new).and_return(mock_llm)
    allow(Langchain::Assistant).to receive(:new).and_return(mock_assistant)
    allow(mock_assistant).to receive(:add_message)
  end

  describe "#call" do
    it "returns the reply with no updated_content when there is no fence block" do
      message = instance_double(Langchain::Assistant::Messages::OpenAIMessage,
                                role: "assistant", content: "Here is my suggestion.")
      allow(mock_assistant).to receive(:add_message_and_run!).and_return([message])

      result = service.call(content: "Some content", message: "Help me")

      expect(result[:reply]).to eq("Here is my suggestion.")
      expect(result[:updated_content]).to be_nil
    end

    it "extracts updated_content from a fenced block and strips it from the reply" do
      reply = "I've improved the report.\n\n~~~report_content\n# Weekly Report\n~~~"
      message = instance_double(Langchain::Assistant::Messages::OpenAIMessage,
                                role: "assistant", content: reply)
      allow(mock_assistant).to receive(:add_message_and_run!).and_return([message])

      result = service.call(content: "Old content", message: "Improve this")

      expect(result[:updated_content]).to eq("# Weekly Report")
      expect(result[:reply]).not_to include("~~~report_content")
    end
  end
end
