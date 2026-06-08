# Example: ActionMailer spec. Build the mail object and assert headers/body.
# In dev these are caught by mailcatcher; in test, delivery_method is :test.
#
# WHY this shape: mirrors spec/mailers/organization_mailer_spec.rb.

require "rails_helper"

RSpec.describe OrganizationMailer do
  describe "#user_added" do
    let(:organization) { create(:organization) }
    let(:user)  { create(:user, preferred_name: "Alice") }
    let(:admin) { create(:user, preferred_name: "Bob") }
    let(:mail)  { described_class.user_added(user: user, party: organization, added_by: admin) }

    it "sends to the added user" do
      expect(mail.to).to eq([user.email])
    end

    it "sets the subject with the party name" do
      expect(mail.subject).to eq("You've been added to #{organization.name}")
    end

    it "uses the configured default from address" do
      expect(mail.from).to eq([ENV.fetch("ACTION_MAILER_DEFAULT_FROM", "from@example.com")])
    end

    it "greets the user by preferred name and names the actor in the body" do
      expect(mail.body.encoded).to include("Hello Alice")
      expect(mail.body.encoded).to include("Bob")
      expect(mail.body.encoded).to include(organization.name)
    end

    context "when the user has no preferred name" do
      let(:user) { create(:user, preferred_name: nil) }

      it "falls back to greeting by email" do
        expect(mail.body.encoded).to include("Hello #{user.email}")
      end
    end

    context "when the party is a team" do
      let(:team) { create(:team, organization: organization) }
      let(:mail) { described_class.user_added(user: user, party: team, added_by: admin) }

      it "names the team in the subject and body" do
        expect(mail.subject).to eq("You've been added to #{team.name}")
        expect(mail.body.encoded).to include("team")
      end
    end
  end
end
