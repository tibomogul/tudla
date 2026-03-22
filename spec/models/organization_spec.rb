require 'rails_helper'

RSpec.describe Organization, type: :model do
  describe "#llm_configured?" do
    it "returns true when all three LLM fields are present" do
      org = build(:organization, llm_api_key: "sk-test", llm_api_base: "https://api.openai.com/v1", llm_model: "gpt-4o-mini")
      expect(org.llm_configured?).to be true
    end

    it "returns false when all fields are blank" do
      org = build(:organization)
      expect(org.llm_configured?).to be false
    end

    it "returns false when api_key is blank" do
      org = build(:organization, llm_api_base: "https://api.openai.com/v1", llm_model: "gpt-4o-mini")
      expect(org.llm_configured?).to be false
    end

    it "returns false when api_base is blank" do
      org = build(:organization, llm_api_key: "sk-test", llm_model: "gpt-4o-mini")
      expect(org.llm_configured?).to be false
    end

    it "returns false when model is blank" do
      org = build(:organization, llm_api_key: "sk-test", llm_api_base: "https://api.openai.com/v1")
      expect(org.llm_configured?).to be false
    end
  end

  describe "llm_settings_completeness validation" do
    it "is valid when all LLM fields are blank" do
      org = build(:organization)
      expect(org).to be_valid
    end

    it "is valid when all LLM fields are present" do
      org = build(:organization, llm_api_key: "sk-test", llm_api_base: "https://api.openai.com/v1", llm_model: "gpt-4o-mini")
      expect(org).to be_valid
    end

    it "is invalid with partial LLM config (key only)" do
      org = build(:organization, llm_api_key: "sk-test")
      expect(org).not_to be_valid
      expect(org.errors[:llm_api_base]).to include(/required when other LLM settings/)
      expect(org.errors[:llm_model]).to include(/required when other LLM settings/)
    end

    it "is invalid with partial LLM config (key and base, no model)" do
      org = build(:organization, llm_api_key: "sk-test", llm_api_base: "https://api.openai.com/v1")
      expect(org).not_to be_valid
      expect(org.errors[:llm_model]).to include(/required when other LLM settings/)
    end
  end

  describe "llm_api_base format validation" do
    it "accepts a valid HTTPS URL" do
      org = build(:organization, llm_api_key: "sk-test", llm_api_base: "https://api.openai.com/v1", llm_model: "gpt-4o-mini")
      expect(org).to be_valid
    end

    it "accepts a valid HTTP URL" do
      org = build(:organization, llm_api_key: "sk-test", llm_api_base: "http://localhost:8080/v1", llm_model: "gpt-4o-mini")
      expect(org).to be_valid
    end

    it "rejects a non-URL string" do
      org = build(:organization, llm_api_key: "sk-test", llm_api_base: "not-a-url", llm_model: "gpt-4o-mini")
      expect(org).not_to be_valid
      expect(org.errors[:llm_api_base]).to include(/must be a valid HTTP/)
    end

    it "allows blank (skips format validation)" do
      org = build(:organization, llm_api_base: "")
      expect(org.errors[:llm_api_base]).not_to include(/must be a valid HTTP/)
    end
  end

  describe "bust_members_organizations_cache" do
    it "busts the organizations cache for all members after update" do
      org = create(:organization)
      user = create(:user)
      UserPartyRole.create!(user: user, party: org, role: "admin")

      expect_any_instance_of(User).to receive(:bust_organizations_cache)

      org.update!(name: "Updated Name")
    end
  end

  describe "llm_api_key encryption" do
    it "round-trips the API key through save and reload" do
      org = create(:organization, llm_api_key: "sk-secret-key-123", llm_api_base: "https://api.openai.com/v1", llm_model: "gpt-4o-mini")
      org.reload
      expect(org.llm_api_key).to eq("sk-secret-key-123")
    end
  end
end
