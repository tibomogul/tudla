require 'rails_helper'

RSpec.describe "Organization Settings", type: :request do
  let(:organization) { create(:organization) }
  let(:admin_user) { create(:user) }

  before do
    UserPartyRole.create!(user: admin_user, party: organization, role: "admin")
    sign_in(admin_user)
  end

  describe "GET /organizations/:id/settings" do
    it "renders successfully for org admins" do
      get organization_settings_url(organization)
      expect(response).to be_successful
    end

    it "renders the LLM settings form" do
      get organization_settings_url(organization)
      expect(response.body).to include("LLM Configuration")
      expect(response.body).to include("API Key")
      expect(response.body).to include("API Base URL")
      expect(response.body).to include("Model")
    end

    context "non-admin user" do
      let(:member_user) { create(:user) }

      before do
        UserPartyRole.create!(user: member_user, party: organization, role: "member")
        sign_in(member_user)
      end

      it "redirects with a not-authorized flash" do
        get organization_settings_url(organization)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to match(/not authorized/i)
      end
    end
  end

  describe "PATCH /organizations/:id/settings" do
    let(:llm_params) do
      {
        organization: {
          llm_api_key: "sk-new-key",
          llm_api_base: "https://api.openai.com/v1",
          llm_model: "gpt-4o-mini"
        }
      }
    end

    it "persists LLM settings for admin" do
      patch organization_settings_url(organization), params: llm_params

      expect(response).to redirect_to(organization_settings_path(organization))
      organization.reload
      expect(organization.llm_api_key).to eq("sk-new-key")
      expect(organization.llm_api_base).to eq("https://api.openai.com/v1")
      expect(organization.llm_model).to eq("gpt-4o-mini")
    end

    it "preserves existing API key when blank key is submitted" do
      organization.update!(llm_api_key: "sk-existing", llm_api_base: "https://api.openai.com/v1", llm_model: "gpt-4o-mini")

      patch organization_settings_url(organization), params: {
        organization: {
          llm_api_key: "",
          llm_api_base: "https://api.example.com/v1",
          llm_model: "gpt-4o"
        }
      }

      expect(response).to redirect_to(organization_settings_path(organization))
      organization.reload
      expect(organization.llm_api_key).to eq("sk-existing")
      expect(organization.llm_api_base).to eq("https://api.example.com/v1")
      expect(organization.llm_model).to eq("gpt-4o")
    end

    it "rejects partial LLM config (validation error)" do
      patch organization_settings_url(organization), params: {
        organization: {
          llm_api_key: "sk-test",
          llm_api_base: "",
          llm_model: ""
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("required when other LLM settings")
    end

    it "rejects invalid API base URL" do
      patch organization_settings_url(organization), params: {
        organization: {
          llm_api_key: "sk-test",
          llm_api_base: "not-a-url",
          llm_model: "gpt-4o-mini"
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("must be a valid HTTP")
    end

    it "clears all LLM settings when clear checkbox is checked" do
      organization.update!(llm_api_key: "sk-existing", llm_api_base: "https://api.openai.com/v1", llm_model: "gpt-4o-mini")

      patch organization_settings_url(organization), params: {
        organization: {
          llm_api_key: "",
          llm_api_base: "https://api.openai.com/v1",
          llm_model: "gpt-4o-mini",
          clear_llm_settings: "1"
        }
      }

      expect(response).to redirect_to(organization_settings_path(organization))
      organization.reload
      expect(organization.llm_api_key).to be_nil
      expect(organization.llm_api_base).to be_nil
      expect(organization.llm_model).to be_nil
    end

    context "non-admin user" do
      let(:member_user) { create(:user) }

      before do
        UserPartyRole.create!(user: member_user, party: organization, role: "member")
        sign_in(member_user)
      end

      it "redirects with a not-authorized flash" do
        patch organization_settings_url(organization), params: llm_params
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to match(/not authorized/i)
      end
    end
  end
end
