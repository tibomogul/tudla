require "rails_helper"

RSpec.describe "/cycles", type: :request do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:user) { create(:user) }
  let(:cycle) { create(:cycle, organization: organization) }

  before do
    UserPartyRole.create!(user: user, party: organization, role: "admin")
    sign_in(user)
  end

  describe "GET /index" do
    it "renders a successful response" do
      get cycles_url
      expect(response).to be_successful
    end

    it "displays all active cycles" do
      create(:cycle, organization: organization, name: "Cycle 1")
      create(:cycle, organization: organization, name: "Cycle 2")
      get cycles_url
      expect(response.body).to include("Cycle 1")
      expect(response.body).to include("Cycle 2")
    end

    it "does not display soft-deleted cycles" do
      deleted_cycle = create(:cycle, organization: organization, name: "Deleted Cycle")
      deleted_cycle.destroy
      get cycles_url
      expect(response.body).not_to include("Deleted Cycle")
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      get cycle_url(cycle)
      expect(response).to be_successful
    end

    it "displays cycle details" do
      get cycle_url(cycle)
      expect(response.body).to include(cycle.name)
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_cycle_url
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      get edit_cycle_url(cycle)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      let(:valid_attributes) do
        {
          name: "New Cycle",
          start_date: Date.current,
          end_date: Date.current + 6.weeks
        }
      end

      it "creates a new Cycle" do
        expect {
          post cycles_url, params: { cycle: valid_attributes }
        }.to change(Cycle, :count).by(1)
      end

      it "redirects to the created cycle" do
        post cycles_url, params: { cycle: valid_attributes }
        expect(response).to redirect_to(cycle_url(Cycle.last))
      end
    end

    context "with invalid parameters" do
      let(:invalid_attributes) do
        {
          name: "",
          start_date: Date.current,
          end_date: Date.current - 1.day
        }
      end

      it "does not create a new Cycle" do
        expect {
          post cycles_url, params: { cycle: invalid_attributes }
        }.to change(Cycle, :count).by(0)
      end

      it "renders a response with 422 status" do
        post cycles_url, params: { cycle: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) do
        {
          name: "Updated Cycle Name"
        }
      end

      it "updates the requested cycle" do
        patch cycle_url(cycle), params: { cycle: new_attributes }
        cycle.reload
        expect(cycle.name).to eq("Updated Cycle Name")
      end

      it "redirects to the cycle" do
        patch cycle_url(cycle), params: { cycle: new_attributes }
        expect(response).to redirect_to(cycle_url(cycle))
      end
    end

    context "with invalid parameters" do
      let(:invalid_attributes) do
        {
          name: "",
          end_date: Date.current - 1.day
        }
      end

      it "renders a response with 422 status" do
        patch cycle_url(cycle), params: { cycle: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /destroy" do
    it "raises Pundit::NotAuthorizedError" do
      expect {
        delete cycle_url(cycle)
      }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "does not soft delete the cycle" do
      expect {
        delete cycle_url(cycle)
      }.to raise_error(Pundit::NotAuthorizedError)

      expect(cycle.reload.deleted_at).to be_nil
    end
  end

  describe "PATCH /transition" do
    it "transitions cycle to next state" do
      patch transition_cycle_url(cycle), params: { state: "betting" }
      cycle.reload
      expect(cycle.current_state).to eq("betting")
    end

    it "redirects to the cycle" do
      patch transition_cycle_url(cycle), params: { state: "betting" }
      expect(response).to redirect_to(cycle_url(cycle))
    end

    context "with invalid state transition" do
      it "does not transition to invalid state" do
        patch transition_cycle_url(cycle), params: { state: "completed" }
        cycle.reload
        expect(cycle.current_state).to eq("shaping")
      end
    end
  end

  describe "authorization" do
    let(:non_admin_user) { create(:user) }

    before do
      UserPartyRole.create!(user: non_admin_user, party: organization, role: "member")
      sign_in(non_admin_user)
    end

    it "prevents non-admin from creating cycles" do
      expect {
        post cycles_url, params: { cycle: { name: "Test", start_date: Date.current, end_date: Date.current + 6.weeks } }
      }.to raise_error(Pundit::NotAuthorizedError)

      expect(Cycle.where(name: "Test")).to be_empty
    end

    it "prevents non-admin from updating cycles" do
      expect {
        patch cycle_url(cycle), params: { cycle: { name: "Updated" } }
      }.to raise_error(Pundit::NotAuthorizedError)

      cycle.reload
      expect(cycle.name).not_to eq("Updated")
    end

    it "prevents non-admin from transitioning cycles" do
      expect {
        patch transition_cycle_url(cycle), params: { state: "betting" }
      }.to raise_error(Pundit::NotAuthorizedError)

      cycle.reload
      expect(cycle.current_state).to eq("shaping")
    end

    it "allows non-admin to view cycles" do
      get cycles_url
      expect(response).to be_successful
    end
  end

  describe "organization isolation" do
    let(:other_organization) { create(:organization) }
    let(:other_cycle) { create(:cycle, organization: other_organization, name: "Other Org Cycle") }

    it "does not show cycles from other organizations" do
      cycle
      get cycles_url
      expect(response.body).to include(cycle.name)
      expect(response.body).not_to include(other_cycle.name)
    end

    it "prevents access to cycles from other organizations" do
      get cycle_url(other_cycle)
      expect(response).to have_http_status(:not_found)
    end
  end
end
