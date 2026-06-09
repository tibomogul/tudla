require "rails_helper"

# AttachmentsHelper is intentionally empty — it defines no methods (see
# app/helpers/attachments_helper.rb). There is no presentation logic to
# exercise yet, so rather than leave a pending stub (which provides no value and
# fails CI's "no pending examples" gate) we assert the one thing that is real:
# the module is loaded and mixed into the view-helper context, so any methods
# added to it later will be callable via `helper`. Add behavioural examples here
# when the helper grows real methods.
RSpec.describe AttachmentsHelper, type: :helper do
  it "is mixed into the helper context" do
    expect(helper).to be_a(AttachmentsHelper)
  end
end
