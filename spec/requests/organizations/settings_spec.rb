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

    it "shows coming soon content" do
      get organization_settings_url(organization)
      expect(response.body).to include("coming soon")
    end

    context "non-admin user" do
      let(:member_user) { create(:user) }

      before do
        UserPartyRole.create!(user: member_user, party: organization, role: "member")
        sign_in(member_user)
      end

      it "raises Pundit::NotAuthorizedError" do
        expect {
          get organization_settings_url(organization)
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end
end
