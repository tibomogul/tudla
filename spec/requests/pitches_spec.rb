require "rails_helper"

RSpec.describe "/pitches", type: :request do
  let(:organization) { create(:organization) }
  let(:user) { create(:user) }
  let(:pitch) { create(:pitch, user: user, organization: organization) }

  before do
    UserPartyRole.create!(user: user, party: organization, role: "member")
    sign_in(user)
  end

  describe "GET /index" do
    it "renders a successful response" do
      get pitches_url
      expect(response).to be_successful
    end

    it "displays visible pitches" do
      pitch1 = create(:pitch, user: user, organization: organization, title: "My Pitch")
      pitch1.state_machine.transition_to!(:ready_for_betting)
      get pitches_url
      expect(response.body).to include("My Pitch")
    end

    it "does not display soft-deleted pitches" do
      deleted_pitch = create(:pitch, user: user, organization: organization, title: "Deleted Pitch")
      deleted_pitch.destroy
      get pitches_url
      expect(response.body).not_to include("Deleted Pitch")
    end

    it "respects visibility scope" do
      other_user = create(:user)
      UserPartyRole.create!(user: other_user, party: organization, role: "member")
      create(:pitch, user: other_user, organization: organization, title: "Other Draft")
      # Pitch starts in draft state by default — no transition needed
      get pitches_url
      expect(response.body).not_to include("Other Draft")
    end
  end

    describe "status tab filtering" do
      let!(:draft_pitch) { create(:pitch, user: user, organization: organization, title: "Draft Pitch") }
      let!(:ready_pitch) do
        p = create(:pitch, user: user, organization: organization, title: "Ready Pitch")
        p.state_machine.transition_to!(:ready_for_betting)
        p
      end
      let!(:bet_pitch) do
        p = create(:pitch, user: user, organization: organization, title: "Bet Pitch")
        p.state_machine.transition_to!(:ready_for_betting)
        p.state_machine.transition_to!(:bet)
        p
      end
      let!(:rejected_pitch) do
        p = create(:pitch, user: user, organization: organization, title: "Rejected Pitch")
        p.state_machine.transition_to!(:ready_for_betting)
        p.state_machine.transition_to!(:rejected)
        p
      end

      it "filters by draft status" do
        get pitches_url(status: "draft")
        expect(response.body).to include("Draft Pitch")
        expect(response.body).not_to include("Ready Pitch")
        expect(response.body).not_to include("Bet Pitch")
        expect(response.body).not_to include("Rejected Pitch")
      end

      it "filters by ready_for_betting status" do
        get pitches_url(status: "ready_for_betting")
        expect(response.body).to include("Ready Pitch")
        expect(response.body).not_to include("Draft Pitch")
        expect(response.body).not_to include("Bet Pitch")
        expect(response.body).not_to include("Rejected Pitch")
      end

      it "filters by bet status" do
        get pitches_url(status: "bet")
        expect(response.body).to include("Bet Pitch")
        expect(response.body).not_to include("Draft Pitch")
        expect(response.body).not_to include("Ready Pitch")
        expect(response.body).not_to include("Rejected Pitch")
      end

      it "filters by rejected status" do
        get pitches_url(status: "rejected")
        expect(response.body).to include("Rejected Pitch")
        expect(response.body).not_to include("Draft Pitch")
        expect(response.body).not_to include("Ready Pitch")
        expect(response.body).not_to include("Bet Pitch")
      end

      it "shows all pitches when no status filter" do
        get pitches_url
        expect(response.body).to include("Draft Pitch")
        expect(response.body).to include("Ready Pitch")
        expect(response.body).to include("Bet Pitch")
        expect(response.body).to include("Rejected Pitch")
      end
    end

  describe "GET /show" do
    it "renders a successful response for own draft pitch" do
      get pitch_url(pitch)
      expect(response).to be_successful
    end

    it "displays pitch details" do
      get pitch_url(pitch)
      expect(response.body).to include(pitch.title)
    end

    it "displays ingredient sections" do
      get pitch_url(pitch)
      expect(response.body).to include("Problem")
      expect(response.body).to include("Solution")
      expect(response.body).to include("Rabbit Holes")
      expect(response.body).to include("No-Gos")
    end

    context "when pitch is non-draft and belongs to another user" do
      let(:other_user) { create(:user) }
      let(:other_ready_pitch) do
        p = create(:pitch, user: other_user, organization: organization)
        p.state_machine.transition_to!(:ready_for_betting)
        p
      end

      before do
        UserPartyRole.create!(user: other_user, party: organization, role: "member")
      end

      it "allows member to view non-draft pitch by another user" do
        get pitch_url(other_ready_pitch)
        expect(response).to be_successful
      end
    end

    context "when pitch is draft and belongs to another user" do
      let(:other_user) { create(:user) }
      let(:other_draft_pitch) { create(:pitch, user: other_user, organization: organization) }

      before do
        UserPartyRole.create!(user: other_user, party: organization, role: "member")
        # Pitch starts in draft state by default — no transition needed
      end

      it "prevents access to other user's draft pitch" do
        get pitch_url(other_draft_pitch)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_pitch_url
      expect(response).to be_successful
    end

    it "renders the form with required field markers" do
      get new_pitch_url
      expect(response.body).to include("Title")
      expect(response.body).to include("Appetite")
      expect(response.body).to include("Ingredients")
    end

    it "renders all ingredient fields in the form" do
      get new_pitch_url
      body = response.body
      expect(body).to include("Problem")
      expect(body).to include("Solution")
      expect(body).to include("Rabbit Holes")
      expect(body).to include("No-Gos")
    end
  end

  describe "GET /edit" do
    it "renders a successful response for own pitch" do
      get edit_pitch_url(pitch)
      expect(response).to be_successful
    end

    context "when pitch belongs to another user" do
      let(:other_user) { create(:user) }
      let(:other_pitch) { create(:pitch, user: other_user, organization: organization) }

      before do
        UserPartyRole.create!(user: other_user, party: organization, role: "member")
      end

      it "prevents editing other user's pitch" do
        get edit_pitch_url(other_pitch)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      let(:valid_attributes) do
        {
          title: "New Pitch",
          problem: "Problem statement",
          appetite: 2,
          solution: "Solution sketch",
          rabbit_holes: "Rabbit holes",
          no_gos: "No-gos"
        }
      end

      it "creates a new Pitch" do
        expect {
          post pitches_url, params: { pitch: valid_attributes }
        }.to change(Pitch, :count).by(1)
      end

      it "sets the current user as creator" do
        post pitches_url, params: { pitch: valid_attributes }
        expect(Pitch.last.user).to eq(user)
      end

      it "sets the organization" do
        post pitches_url, params: { pitch: valid_attributes }
        expect(Pitch.last.organization).to eq(organization)
      end

      it "redirects to the created pitch" do
        post pitches_url, params: { pitch: valid_attributes }
        expect(response).to redirect_to(pitch_url(Pitch.last))
      end
    end

    context "with invalid parameters" do
      let(:invalid_attributes) do
        {
          title: "",
          appetite: 3
        }
      end

      it "does not create a new Pitch" do
        expect {
          post pitches_url, params: { pitch: invalid_attributes }
        }.to change(Pitch, :count).by(0)
      end

      it "renders a response with 422 status" do
        post pitches_url, params: { pitch: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) do
        {
          title: "Updated Pitch Title"
        }
      end

      it "updates the requested pitch" do
        patch pitch_url(pitch), params: { pitch: new_attributes }
        pitch.reload
        expect(pitch.title).to eq("Updated Pitch Title")
      end

      it "redirects to the pitch" do
        patch pitch_url(pitch), params: { pitch: new_attributes }
        expect(response).to redirect_to(pitch_url(pitch))
      end
    end

    context "with invalid parameters" do
      let(:invalid_attributes) do
        {
          title: "",
          appetite: 3
        }
      end

      it "renders a response with 422 status" do
        patch pitch_url(pitch), params: { pitch: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when pitch belongs to another user" do
      let(:other_user) { create(:user) }
      let(:other_pitch) { create(:pitch, user: other_user, organization: organization) }

      before do
        UserPartyRole.create!(user: other_user, party: organization, role: "member")
      end

      it "prevents updating other user's pitch" do
        patch pitch_url(other_pitch), params: { pitch: { title: "Hacked" } }
        other_pitch.reload
        expect(other_pitch.title).not_to eq("Hacked")
      end
    end

    context "when user is admin" do
      before do
        UserPartyRole.where(user: user, party: organization).update_all(role: "admin")
      end

      it "allows admin to update another user's non-draft pitch" do
        other_user = create(:user)
        UserPartyRole.create!(user: other_user, party: organization, role: "member")
        other_pitch = create(:pitch, user: other_user, organization: organization)
        other_pitch.state_machine.transition_to!(:ready_for_betting)

        patch pitch_url(other_pitch), params: { pitch: { title: "Admin Edit" } }
        other_pitch.reload
        expect(other_pitch.title).to eq("Admin Edit")
      end

      it "allows admin to update a non-draft pitch" do
        pitch.state_machine.transition_to!(:ready_for_betting)
        patch pitch_url(pitch), params: { pitch: { title: "Updated Ready Pitch" } }
        pitch.reload
        expect(pitch.title).to eq("Updated Ready Pitch")
      end
    end

    context "when creator tries to update non-draft pitch" do
      it "prevents creator from updating ready_for_betting pitch" do
        pitch.state_machine.transition_to!(:ready_for_betting)
        expect {
          patch pitch_url(pitch), params: { pitch: { title: "Sneaky Update" } }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end

  describe "DELETE /destroy" do
    it "soft deletes the pitch" do
      delete pitch_url(pitch)
      expect(pitch.reload.deleted_at).to be_present
    end

    it "redirects to the pitches list" do
      delete pitch_url(pitch)
      expect(response).to redirect_to(pitches_url)
    end

    context "when pitch belongs to another user" do
      let(:other_user) { create(:user) }
      let(:other_pitch) { create(:pitch, user: other_user, organization: organization) }

      before do
        UserPartyRole.create!(user: other_user, party: organization, role: "member")
      end

      it "prevents deleting other user's pitch" do
        delete pitch_url(other_pitch)
        expect(other_pitch.reload.deleted_at).to be_nil
      end
    end

    context "when pitch is not in draft state" do
      it "prevents creator from deleting non-draft pitch" do
        pitch.state_machine.transition_to!(:ready_for_betting)
        expect {
          delete pitch_url(pitch)
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end

  describe "PATCH /transition" do
    it "transitions pitch to ready_for_betting" do
      patch transition_pitch_url(pitch), params: { state: "ready_for_betting" }
      pitch.reload
      expect(pitch.current_state).to eq("ready_for_betting")
    end

    it "transitions pitch from ready_for_betting to bet" do
      UserPartyRole.where(user: user, party: organization).update_all(role: "admin")
      pitch.state_machine.transition_to!(:ready_for_betting)
      patch transition_pitch_url(pitch), params: { state: "bet" }
      pitch.reload
      expect(pitch.current_state).to eq("bet")
    end

    it "transitions pitch from ready_for_betting to rejected" do
      UserPartyRole.where(user: user, party: organization).update_all(role: "admin")
      pitch.state_machine.transition_to!(:ready_for_betting)
      patch transition_pitch_url(pitch), params: { state: "rejected" }
      pitch.reload
      expect(pitch.current_state).to eq("rejected")
    end

    it "allows rework: rejected to draft" do
      UserPartyRole.where(user: user, party: organization).update_all(role: "admin")
      pitch.state_machine.transition_to!(:ready_for_betting)
      pitch.state_machine.transition_to!(:rejected)
      patch transition_pitch_url(pitch), params: { state: "draft" }
      pitch.reload
      expect(pitch.current_state).to eq("draft")
    end

    it "redirects to the pitch" do
      patch transition_pitch_url(pitch), params: { state: "ready_for_betting" }
      expect(response).to redirect_to(pitch_url(pitch))
    end

    it "stores user_id in transition metadata" do
      patch transition_pitch_url(pitch), params: { state: "ready_for_betting" }
      transition = pitch.pitch_transitions.order(:sort_key).last
      expect(transition.metadata["user_id"]).to eq(user.id)
    end

    it "returns turbo_stream for betting_table context rejection" do
      UserPartyRole.where(user: user, party: organization).update_all(role: "admin")
      pitch.state_machine.transition_to!(:ready_for_betting)
      cycle = create(:cycle, organization: organization)

      patch transition_pitch_url(pitch),
        params: { state: "rejected", update_context: "betting_table", cycle_id: cycle.id },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("betting_card")
    end

    context "with invalid state transition" do
      it "does not transition to invalid state" do
        UserPartyRole.where(user: user, party: organization).update_all(role: "admin")
        patch transition_pitch_url(pitch), params: { state: "bet" }
        pitch.reload
        expect(pitch.current_state).to eq("draft")
      end
    end

    context "when pitch belongs to another user" do
      let(:other_user) { create(:user) }
      let(:other_pitch) { create(:pitch, user: other_user, organization: organization) }

      before do
        UserPartyRole.create!(user: other_user, party: organization, role: "member")
      end

      it "prevents transitioning other user's pitch" do
        patch transition_pitch_url(other_pitch), params: { state: "ready_for_betting" }
        other_pitch.reload
        expect(other_pitch.current_state).to eq("draft")
      end
    end
  end

  describe "POST /bet" do
    before do
      pitch.state_machine.transition_to!(:ready_for_betting)
      UserPartyRole.where(user: user, party: organization).update_all(role: "admin")
    end

    it "creates a project from the pitch" do
      team = create(:team, organization: organization)
      cycle = create(:cycle, organization: organization)

      expect {
        post bet_pitch_url(pitch), params: { team_id: team.id, cycle_id: cycle.id }
      }.to change(Project, :count).by(1)
    end

    it "associates the project with the pitch" do
      team = create(:team, organization: organization)
      cycle = create(:cycle, organization: organization)

      post bet_pitch_url(pitch), params: { team_id: team.id, cycle_id: cycle.id }
      expect(pitch.projects).to include(Project.last)
    end

    it "redirects to the created project" do
      team = create(:team, organization: organization)
      cycle = create(:cycle, organization: organization)

      post bet_pitch_url(pitch), params: { team_id: team.id, cycle_id: cycle.id }
      expect(response).to redirect_to(project_url(Project.last))
    end

    it "transitions pitch to bet state" do
      team = create(:team, organization: organization)
      cycle = create(:cycle, organization: organization)

      post bet_pitch_url(pitch), params: { team_id: team.id, cycle_id: cycle.id }
      pitch.reload
      expect(pitch.current_state).to eq("bet")
    end

    context "when user is not admin" do
      before do
        UserPartyRole.where(user: user, party: organization).update_all(role: "member")
      end

      it "prevents non-admin from betting" do
        team = create(:team, organization: organization)
        cycle = create(:cycle, organization: organization)

        expect {
          post bet_pitch_url(pitch), params: { team_id: team.id, cycle_id: cycle.id }
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    it "redirects with error when team_id is blank" do
      cycle = create(:cycle, organization: organization)

      post bet_pitch_url(pitch), params: { cycle_id: cycle.id }
      expect(response).to redirect_to(pitch_url(pitch))
      follow_redirect!
      expect(response.body).to include("Please select a team")
    end

    it "returns turbo_stream when requested" do
      team = create(:team, organization: organization)
      cycle = create(:cycle, organization: organization)

      post bet_pitch_url(pitch), params: { team_id: team.id, cycle_id: cycle.id },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("turbo-stream")
    end

    context "when pitch is not in bet state" do
      let(:draft_pitch) { create(:pitch, user: user, organization: organization) }

      it "prevents creating project from draft pitch" do
        team = create(:team, organization: organization)
        cycle = create(:cycle, organization: organization)
        initial_project_count = Project.count

        expect {
          post bet_pitch_url(draft_pitch), params: { team_id: team.id, cycle_id: cycle.id }
        }.to raise_error(Statesman::TransitionFailedError)

        expect(Project.count).to eq(initial_project_count)
      end
    end
  end

  describe "authorization" do
    let(:non_member_user) { create(:user) }

    before do
      sign_in(non_member_user)
    end

    it "prevents non-member from creating pitches" do
      expect {
        post pitches_url, params: { pitch: { title: "Test", appetite: 2 } }
      }.to raise_error(Pundit::NotAuthorizedError)

      expect(Pitch.where(title: "Test")).to be_empty
    end

    it "allows member to view pitches" do
      UserPartyRole.create!(user: non_member_user, party: organization, role: "member")
      get pitches_url
      expect(response).to be_successful
    end
  end

  describe "unauthenticated access" do
    before { sign_out user }

    it "redirects index to root" do
      get pitches_url
      expect(response).to redirect_to(root_path)
    end

    it "redirects show to root" do
      get pitch_url(pitch)
      expect(response).to redirect_to(root_path)
    end

    it "redirects create to root" do
      post pitches_url, params: { pitch: { title: "Test", appetite: 2 } }
      expect(response).to redirect_to(root_path)
    end
  end

  describe "organization isolation" do
    let(:other_organization) { create(:organization) }
    let(:other_pitch) { create(:pitch, user: user, organization: other_organization, title: "Other Org Pitch") }

    it "does not show pitches from other organizations" do
      pitch
      get pitches_url
      expect(response.body).to include(pitch.title)
      expect(response.body).not_to include(other_pitch.title)
    end

    it "prevents access to pitches from other organizations" do
      get pitch_url(other_pitch)
      expect(response).to have_http_status(:not_found)
    end
  end
end
