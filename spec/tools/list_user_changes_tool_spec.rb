# frozen_string_literal: true

require "rails_helper"

RSpec.describe ListUserChangesTool, type: :model do
  let(:organization) { create(:organization, name: "Test Org") }
  let(:team) { create(:team, name: "Test Team", organization: organization) }
  let(:user) do
    create(:user, email: "testuser@example.com", username: "testuser", confirmation_token: "token_user1").tap do |u|
      UserPartyRole.create!(user: u, party: team)
    end
  end
  let(:other_user) do
    create(:user, email: "otheruser@example.com", username: "otheruser", confirmation_token: "token_user2").tap do |u|
      UserPartyRole.create!(user: u, party: team)
    end
  end
  let(:project) { create(:project, name: "Test Project", team: team) }
  let(:task) { create(:task, name: "Test Task", project: project) }

  let(:tool) { described_class.new({ user: user }) }

  before do
    PaperTrail.enabled = true
  end

  after do
    PaperTrail.enabled = false
  end

  # Helper to create a note attached to a record via notable
  def create_note_for(record, user:, content: "Test note")
    notable = record.notable || record.create_notable!
    PaperTrail.request.whodunnit = user.id.to_s
    notable.notes.create!(content: content, user: user)
  end

  # Helper to create a link attached to a record via linkable
  def create_link_for(record, user:, url: "https://example.com")
    linkable = record.linkable || record.create_linkable!
    PaperTrail.request.whodunnit = user.id.to_s
    linkable.links.create!(url: url, user: user)
  end

  # Helper to create an attachment attached to a record via attachable
  def create_attachment_for(record, user:, description: "Test file")
    attachable = record.attachable || record.create_attachable!
    PaperTrail.request.whodunnit = user.id.to_s
    attachment = attachable.attachments.build(user: user, description: description)
    attachment.file.attach(
      io: StringIO.new("test content"),
      filename: "test.txt",
      content_type: "text/plain"
    )
    attachment.save!
    attachment
  end

  describe "#execute" do
    context "current user changes (no team_id)" do
      it "includes Note changes made by the current user" do
        note = create_note_for(task, user: user, content: "My note")

        result = tool.execute

        expect(result).to include("Note")
        expect(result).to include("change")
      end

      it "includes Link changes made by the current user" do
        link = create_link_for(task, user: user, url: "https://test.com")

        result = tool.execute

        expect(result).to include("Link")
        expect(result).to include("change")
      end

      it "includes Attachment changes made by the current user" do
        attachment = create_attachment_for(task, user: user)

        result = tool.execute

        expect(result).to include("Attachment")
        expect(result).to include("change")
      end

      it "does not include changes by other users" do
        create_note_for(task, user: other_user, content: "Other user note")

        result = tool.execute

        expect(result).to include("No changes found")
      end
    end

    context "team changes (with team_id)" do
      it "includes Note changes by team members on team projects" do
        note = create_note_for(task, user: other_user, content: "Team note")

        result = tool.execute(team_id: team.id)

        expect(result).to include("Note")
        expect(result).to include("change")
      end

      it "includes Link changes by team members on team projects" do
        link = create_link_for(task, user: other_user, url: "https://team-link.com")

        result = tool.execute(team_id: team.id)

        expect(result).to include("Link")
        expect(result).to include("change")
      end

      it "includes Attachment changes by team members on team projects" do
        attachment = create_attachment_for(task, user: other_user)

        result = tool.execute(team_id: team.id)

        expect(result).to include("Attachment")
        expect(result).to include("change")
      end

      it "includes Notes on scopes within team projects" do
        scope = create(:scope, name: "Test Scope", project: project)
        create_note_for(scope, user: other_user, content: "Scope note")

        result = tool.execute(team_id: team.id)

        expect(result).to include("Note")
      end

      it "includes Notes on projects directly" do
        create_note_for(project, user: other_user, content: "Project note")

        result = tool.execute(team_id: team.id)

        expect(result).to include("Note")
      end

      it "includes Links on projects directly" do
        create_link_for(project, user: other_user, url: "https://project-link.com")

        result = tool.execute(team_id: team.id)

        expect(result).to include("Link")
      end

      it "excludes Notes from other teams" do
        other_org = create(:organization, name: "Other Org")
        other_team = create(:team, name: "Other Team", organization: other_org)
        other_project = create(:project, name: "Other Project", team: other_team)
        other_task = create(:task, name: "Other Task", project: other_project)

        # Create note by other_user on a task NOT in our team
        PaperTrail.request.whodunnit = other_user.id.to_s
        notable = other_task.create_notable!
        notable.notes.create!(content: "Other team note", user: other_user)

        result = tool.execute(team_id: team.id)

        # Should not contain "Other team note" context - either no changes or only our team's
        note_versions = PaperTrail::Version.where(item_type: "Note")
        expect(note_versions.count).to be >= 1

        # The result should not include changes from other team's items
        expect(result).not_to include("Other Task")
      end
    end
  end

  describe "#format_associated_record_context" do
    it "returns parent context for a Note version" do
      note = create_note_for(task, user: user, content: "Context note")
      version = PaperTrail::Version.where(item_type: "Note", item_id: note.id).last

      result = tool.send(:format_associated_record_context, version)

      expect(result).to include("Parent: Task")
      expect(result).to include("Test Task")
    end

    it "returns parent context for a Link version" do
      link = create_link_for(task, user: user, url: "https://context.com")
      version = PaperTrail::Version.where(item_type: "Link", item_id: link.id).last

      result = tool.send(:format_associated_record_context, version)

      expect(result).to include("Parent: Task")
      expect(result).to include("Test Task")
    end

    it "returns parent context for an Attachment version" do
      attachment = create_attachment_for(task, user: user)
      version = PaperTrail::Version.where(item_type: "Attachment", item_id: attachment.id).last

      result = tool.send(:format_associated_record_context, version)

      expect(result).to include("Parent: Task")
      expect(result).to include("Test Task")
    end

    it "returns parent context when note is on a Project" do
      note = create_note_for(project, user: user, content: "Project note")
      version = PaperTrail::Version.where(item_type: "Note", item_id: note.id).last

      result = tool.send(:format_associated_record_context, version)

      expect(result).to include("Parent: Project")
      expect(result).to include("Test Project")
    end

    it "returns empty string for unknown item type" do
      version = double(item_type: "Unknown", item_id: 999)

      result = tool.send(:format_associated_record_context, version)

      expect(result).to eq("")
    end

    it "returns empty string when record not found" do
      version = double(item_type: "Note", item_id: -1)

      result = tool.send(:format_associated_record_context, version)

      expect(result).to eq("")
    end
  end

  describe "#filter_by_team" do
    let(:all_versions) { PaperTrail::Version.all }

    context "primary item types" do
      it "includes Task versions for tasks in team projects" do
        PaperTrail.request.whodunnit = user.id.to_s
        task.update!(name: "Updated Task")

        filtered = tool.send(:filter_by_team, all_versions, team)

        expect(filtered.exists?(item_type: "Task", item_id: task.id)).to be true
      end

      it "includes Scope versions for scopes in team projects" do
        scope = create(:scope, name: "Team Scope", project: project)
        PaperTrail.request.whodunnit = user.id.to_s
        scope.update!(name: "Updated Scope")

        filtered = tool.send(:filter_by_team, all_versions, team)

        expect(filtered.exists?(item_type: "Scope", item_id: scope.id)).to be true
      end

      it "includes Project versions for team projects" do
        PaperTrail.request.whodunnit = user.id.to_s
        project.update!(name: "Updated Project")

        filtered = tool.send(:filter_by_team, all_versions, team)

        expect(filtered.exists?(item_type: "Project", item_id: project.id)).to be true
      end

      it "excludes Task versions for tasks NOT in team projects" do
        other_org = create(:organization, name: "Excluded Org")
        other_team = create(:team, name: "Excluded Team", organization: other_org)
        other_project = create(:project, name: "Excluded Project", team: other_team)
        other_task = create(:task, name: "Excluded Task", project: other_project)
        PaperTrail.request.whodunnit = user.id.to_s
        other_task.update!(name: "Should Not Appear")

        filtered = tool.send(:filter_by_team, all_versions, team)

        expect(filtered.exists?(item_type: "Task", item_id: other_task.id)).to be false
      end

      it "excludes Scope versions for scopes NOT in team projects" do
        other_org = create(:organization, name: "Excluded Org S")
        other_team = create(:team, name: "Excluded Team S", organization: other_org)
        other_project = create(:project, name: "Excluded Project S", team: other_team)
        other_scope = create(:scope, name: "Excluded Scope", project: other_project)

        filtered = tool.send(:filter_by_team, all_versions, team)

        expect(filtered.exists?(item_type: "Scope", item_id: other_scope.id)).to be false
      end

      it "excludes Project versions for projects NOT in team" do
        other_org = create(:organization, name: "Excluded Org P")
        other_team = create(:team, name: "Excluded Team P", organization: other_org)
        other_project = create(:project, name: "Excluded Project P", team: other_team)

        filtered = tool.send(:filter_by_team, all_versions, team)

        expect(filtered.exists?(item_type: "Project", item_id: other_project.id)).to be false
      end
    end

    context "polymorphic items (Note, Link, Attachment)" do
      it "includes Note versions for notes on team tasks" do
        note = create_note_for(task, user: user)

        filtered = tool.send(:filter_by_team, all_versions, team)

        expect(filtered.exists?(item_type: "Note", item_id: note.id)).to be true
      end

      it "includes Link versions for links on team tasks" do
        link = create_link_for(task, user: user)

        filtered = tool.send(:filter_by_team, all_versions, team)

        expect(filtered.exists?(item_type: "Link", item_id: link.id)).to be true
      end

      it "includes Attachment versions for attachments on team tasks" do
        attachment = create_attachment_for(task, user: user)

        filtered = tool.send(:filter_by_team, all_versions, team)

        expect(filtered.exists?(item_type: "Attachment", item_id: attachment.id)).to be true
      end

      it "includes Note versions for notes on team scopes" do
        scope = create(:scope, name: "Noted Scope", project: project)
        note = create_note_for(scope, user: user, content: "Scope note")

        filtered = tool.send(:filter_by_team, all_versions, team)

        expect(filtered.exists?(item_type: "Note", item_id: note.id)).to be true
      end

      it "includes Link versions for links on team projects" do
        link = create_link_for(project, user: user, url: "https://proj.com")

        filtered = tool.send(:filter_by_team, all_versions, team)

        expect(filtered.exists?(item_type: "Link", item_id: link.id)).to be true
      end

      it "includes Attachment versions for attachments on team projects" do
        attachment = create_attachment_for(project, user: user)

        filtered = tool.send(:filter_by_team, all_versions, team)

        expect(filtered.exists?(item_type: "Attachment", item_id: attachment.id)).to be true
      end

      it "excludes Note versions for notes on non-team tasks" do
        other_org = create(:organization, name: "Other Org 2")
        other_team = create(:team, name: "Other Team 2", organization: other_org)
        other_project = create(:project, name: "Other Project 2", team: other_team)
        other_task = create(:task, name: "Other Task 2", project: other_project)

        note = create_note_for(other_task, user: user)

        filtered = tool.send(:filter_by_team, all_versions, team)

        expect(filtered.exists?(item_type: "Note", item_id: note.id)).to be false
      end

      it "excludes Link versions for links on non-team tasks" do
        other_org = create(:organization, name: "Other Org 3")
        other_team = create(:team, name: "Other Team 3", organization: other_org)
        other_project = create(:project, name: "Other Project 3", team: other_team)
        other_task = create(:task, name: "Other Task 3", project: other_project)

        link = create_link_for(other_task, user: user)

        filtered = tool.send(:filter_by_team, all_versions, team)

        expect(filtered.exists?(item_type: "Link", item_id: link.id)).to be false
      end

      it "excludes Attachment versions for attachments on non-team tasks" do
        other_org = create(:organization, name: "Other Org 4")
        other_team = create(:team, name: "Other Team 4", organization: other_org)
        other_project = create(:project, name: "Other Project 4", team: other_team)
        other_task = create(:task, name: "Other Task 4", project: other_project)

        attachment = create_attachment_for(other_task, user: user)

        filtered = tool.send(:filter_by_team, all_versions, team)

        expect(filtered.exists?(item_type: "Attachment", item_id: attachment.id)).to be false
      end
    end

    context "soft-deleted records" do
      it "excludes versions for soft-deleted tasks" do
        PaperTrail.request.whodunnit = user.id.to_s
        deleted_task = create(:task, name: "Will Delete", project: project)
        deleted_task.update!(name: "Before Delete")
        deleted_task.soft_delete

        filtered = tool.send(:filter_by_team, all_versions, team)

        expect(filtered.exists?(item_type: "Task", item_id: deleted_task.id)).to be false
      end

      it "excludes versions for soft-deleted scopes" do
        PaperTrail.request.whodunnit = user.id.to_s
        deleted_scope = create(:scope, name: "Will Delete Scope", project: project)
        deleted_scope.soft_delete

        filtered = tool.send(:filter_by_team, all_versions, team)

        expect(filtered.exists?(item_type: "Scope", item_id: deleted_scope.id)).to be false
      end

      it "excludes versions for soft-deleted projects" do
        PaperTrail.request.whodunnit = user.id.to_s
        deleted_project = create(:project, name: "Will Delete Project", team: team)
        deleted_project.soft_delete

        filtered = tool.send(:filter_by_team, all_versions, team)

        expect(filtered.exists?(item_type: "Project", item_id: deleted_project.id)).to be false
      end

      it "excludes versions for soft-deleted notes" do
        note = create_note_for(task, user: user, content: "Will delete note")
        note.soft_delete

        filtered = tool.send(:filter_by_team, all_versions, team)

        expect(filtered.exists?(item_type: "Note", item_id: note.id)).to be false
      end
    end

    context "edge cases" do
      it "returns none when team has no active projects" do
        empty_org = create(:organization, name: "Empty Org")
        empty_team = create(:team, name: "Empty Team", organization: empty_org)

        filtered = tool.send(:filter_by_team, all_versions, empty_team)

        expect(filtered).to be_empty
      end

      it "returns correct results with mixed item types" do
        PaperTrail.request.whodunnit = user.id.to_s
        task.update!(name: "Changed Task")
        scope = create(:scope, name: "Mixed Scope", project: project)
        note = create_note_for(task, user: user, content: "Mixed note")

        filtered = tool.send(:filter_by_team, all_versions, team)

        item_types = filtered.distinct.pluck(:item_type)
        expect(item_types).to include("Task", "Scope", "Note")
      end
    end
  end
end
