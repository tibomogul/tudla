# Example: ActiveJob spec (Solid Queue is the adapter). Assert enqueueing with
# have_enqueued_job, or run inline with perform_enqueued_jobs and assert the
# side effect. Include ActiveJob::TestHelper for the helpers/matchers.
#
# Replace NotifyReviewersJob / the trigger with the real job under test.

require "rails_helper"

RSpec.describe NotifyReviewersJob, type: :job do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization) }
  let(:team)         { create(:team, organization: organization) }
  let(:project)      { create(:project, team: team) }
  let(:reviewer)     { create(:user) }
  let(:task) do
    create(:task, project: project, responsible_user: reviewer,
                  unassisted_estimate: 5, ai_assisted_estimate: 3)
  end

  describe "enqueueing" do
    it "is enqueued when a task moves into review" do
      task.state_machine.transition_to!(:in_progress, user_id: reviewer.id)
      expect {
        task.state_machine.transition_to!(:in_review, user_id: reviewer.id)
      }.to have_enqueued_job(described_class).with(task)
    end
  end

  describe "#perform" do
    it "delivers a review notification" do
      # WHY: run the job inline and assert the observable effect, not that an
      # internal method was called. Stub the mailer to keep the unit focused.
      mail = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
      allow(TaskMailer).to receive(:review_requested).with(task).and_return(mail)

      perform_enqueued_jobs { described_class.perform_later(task) }

      expect(TaskMailer).to have_received(:review_requested).with(task)
    end
  end
end
