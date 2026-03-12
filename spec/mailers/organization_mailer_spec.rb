require "rails_helper"

RSpec.describe OrganizationMailer do
  describe "#user_added" do
    let(:organization) { create(:organization) }
    let(:user) { create(:user, preferred_name: "Alice") }
    let(:admin) { create(:user, preferred_name: "Bob") }
    let(:mail) { described_class.user_added(user: user, party: organization, added_by: admin) }

    it "sends to the correct recipient" do
      expect(mail.to).to eq([ user.email ])
    end

    it "sets the subject with the party name" do
      expect(mail.subject).to eq("You've been added to #{organization.name}")
    end

    it "uses the default from address" do
      expect(mail.from).to eq([ ENV.fetch("ACTION_MAILER_DEFAULT_FROM", "from@example.com") ])
    end

    it "includes the added_by user preferred name in the body" do
      expect(mail.body.encoded).to include("Bob")
    end

    it "includes the party name in the body" do
      expect(mail.body.encoded).to include(organization.name)
    end

    it "includes the party type in the body" do
      expect(mail.body.encoded).to include("organization")
    end

    it "includes a sign-in link" do
      expect(mail.body.encoded).to include("Sign in to Tudla")
    end

    it "greets the user by preferred name" do
      expect(mail.body.encoded).to include("Hello Alice")
    end

    context "when user has no preferred name" do
      let(:user) { create(:user, preferred_name: nil) }

      it "greets the user by email" do
        expect(mail.body.encoded).to include("Hello #{user.email}")
      end
    end

    context "when user has blank preferred name" do
      let(:user) { create(:user, preferred_name: "") }

      it "greets the user by email" do
        expect(mail.body.encoded).to include("Hello #{user.email}")
      end
    end

    context "when added_by has no preferred name" do
      let(:admin) { create(:user, preferred_name: nil) }

      it "shows the added_by email in the body" do
        expect(mail.body.encoded).to include(admin.email)
      end
    end

    context "when party is a team" do
      let(:team) { create(:team, organization: organization) }
      let(:mail) { described_class.user_added(user: user, party: team, added_by: admin) }

      it "sets the subject with the team name" do
        expect(mail.subject).to eq("You've been added to #{team.name}")
      end

      it "includes 'team' as the party type in the body" do
        expect(mail.body.encoded).to include("team")
      end

      it "includes the team name in the body" do
        expect(mail.body.encoded).to include(team.name)
      end
    end

    context "when party is a project" do
      let(:team) { create(:team, organization: organization) }
      let(:project) { create(:project, team: team) }
      let(:mail) { described_class.user_added(user: user, party: project, added_by: admin) }

      it "sets the subject with the project name" do
        expect(mail.subject).to eq("You've been added to #{project.name}")
      end

      it "includes 'project' as the party type in the body" do
        expect(mail.body.encoded).to include("project")
      end
    end
  end
end
