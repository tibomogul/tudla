require "rails_helper"

RSpec.describe "/reports AI assist", type: :request do
  let(:organization) { create(:organization, llm_api_key: "sk-test", llm_api_base: "https://api.openai.com/v1", llm_model: "gpt-4o-mini") }
  let(:team) { create(:team, organization: organization) }
  let(:user) { create(:user) }

  before do
    UserPartyRole.create!(user: user, party: team, role: "admin")
    sign_in(user)
  end

  describe "POST /reports/ai_assist" do
    let(:ai_assist_params) do
      {
        content: "# Weekly Report\n\nSome content here.",
        message: "Make this more detailed",
        conversation_history: []
      }
    end

    let(:mock_service) { instance_double(ReportAiAssistService) }

    before do
      allow(ReportAiAssistService).to receive(:new).and_return(mock_service)
    end

    it "requires authentication" do
      sign_out(user)
      post ai_assist_reports_path, params: ai_assist_params, as: :json
      expect(response).to redirect_to(root_path)
    end

    it "returns JSON with reply key" do
      allow(mock_service).to receive(:call).and_return({ reply: "Here is my suggestion.", updated_content: nil })

      post ai_assist_reports_path, params: ai_assist_params, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["reply"]).to eq("Here is my suggestion.")
      expect(json["updated_content"]).to be_nil
    end

    it "passes current_organization to the service" do
      allow(mock_service).to receive(:call).and_return({ reply: "OK", updated_content: nil })

      post ai_assist_reports_path, params: ai_assist_params, as: :json

      expect(ReportAiAssistService).to have_received(:new).with(user: user, organization: organization)
    end

    it "returns updated_content when service provides it" do
      allow(mock_service).to receive(:call).and_return({
        reply: "I've updated the report content.",
        updated_content: "# Weekly Report\n\nDetailed content here."
      })

      post ai_assist_reports_path, params: ai_assist_params, as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["updated_content"]).to eq("# Weekly Report\n\nDetailed content here.")
    end

    it "passes conversation history to the service" do
      history = [
        { "role" => "user", "content" => "Hello" },
        { "role" => "assistant", "content" => "Hi there!" }
      ]

      allow(mock_service).to receive(:call).and_return({ reply: "Sure!", updated_content: nil })

      post ai_assist_reports_path,
        params: ai_assist_params.merge(conversation_history: history),
        as: :json

      expect(mock_service).to have_received(:call) do |args|
        expect(args[:content]).to eq(ai_assist_params[:content])
        expect(args[:message]).to eq(ai_assist_params[:message])
        expect(args[:conversation_history]).to all(be_a(Hash))
        expect(args[:conversation_history]).to eq(history)
      end
    end

    it "returns 400 when message param is missing" do
      post ai_assist_reports_path,
        params: { content: "Some content" },
        as: :json

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["reply"]).to eq("Message is required.")
    end

    context "integration (real service, stubbed LLM)" do
      let(:mock_llm) { instance_double(Langchain::LLM::OpenAI) }
      let(:mock_assistant) { instance_double(Langchain::Assistant) }

      before do
        allow(ReportAiAssistService).to receive(:new).and_call_original
        allow(Langchain::LLM::OpenAI).to receive(:new).and_return(mock_llm)
        allow(Langchain::Assistant).to receive(:new).and_return(mock_assistant)
        allow(mock_assistant).to receive(:add_message)
      end

      it "processes ActionController::Parameters through the real service" do
        reply_msg = instance_double(Langchain::Assistant::Messages::OpenAIMessage, role: "assistant", content: "Looks good!")
        allow(mock_assistant).to receive(:add_message_and_run!).and_return([ reply_msg ])

        history = [
          { "role" => "user", "content" => "Hello" },
          { "role" => "assistant", "content" => "Hi!" }
        ]

        post ai_assist_reports_path,
          params: ai_assist_params.merge(conversation_history: history),
          as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["reply"]).to eq("Looks good!")

        # Verify content preamble was sent as user+assistant message pair
        expect(mock_assistant).to have_received(:add_message).with(
          role: "user", content: a_string_matching(/Here is my current report content/)
        )
        expect(mock_assistant).to have_received(:add_message).with(
          role: "assistant", content: a_string_matching(/Got it/)
        )

        # Verify history was replayed (proves sanitize_history handled ActionController::Parameters)
        expect(mock_assistant).to have_received(:add_message).with(role: "user", content: "Hello")
        expect(mock_assistant).to have_received(:add_message).with(role: "assistant", content: "Hi!")
      end
    end

    it "returns generic error message on service failure" do
      allow(mock_service).to receive(:call).and_raise(
        ReportAiAssistService::Error, "Sorry, something went wrong while processing your request."
      )

      post ai_assist_reports_path, params: ai_assist_params, as: :json

      expect(response).to have_http_status(:internal_server_error)
      json = JSON.parse(response.body)
      expect(json["reply"]).to eq("Sorry, something went wrong while processing your request.")
      expect(json["reply"]).not_to include("LLM")
      expect(json["updated_content"]).to be_nil
    end
  end

  describe "POST /reports/render_markdown" do
    it "returns sanitized rendered HTML for given markdown content" do
      post render_markdown_reports_path,
        params: { content: "# Hello\n\n**bold** text" },
        as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["html"]).to include("<h1>")
      expect(json["html"]).to include("Hello")
      expect(json["html"]).to include("<strong>bold</strong>")
    end

    it "handles empty content" do
      post render_markdown_reports_path,
        params: { content: "" },
        as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key("html")
    end

    it "requires authentication" do
      sign_out(user)
      post render_markdown_reports_path, params: { content: "test" }, as: :json
      expect(response).to redirect_to(root_path)
    end
  end
end
