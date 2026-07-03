# Host-app visibility filtering for Pulse fan-out. Replaces the default
# per-recipient Pundit check (~3 role queries per recipient) with a single
# UserPartyRole query for the whole recipient set.
#
# Must stay in agreement with ProjectPolicy/ScopePolicy/TaskPolicy #show?:
# membership at any level of the project → team → organization hierarchy
# grants visibility, plus task ownership. Guarded by
# spec/services/pulse_visibility_filter_spec.rb, which asserts agreement with
# the policies for every subject type and role placement.
class PulseVisibilityFilter < Pulse::VisibilityFilter
  def call(subject, recipients)
    project = subject_project(subject)
    return super unless project # unknown subject shape → per-recipient Pundit

    parties = [ project, project.team, project.team&.organization ].compact
    member_ids = UserPartyRole
      .where(user_id: recipients.map(&:id), party: parties)
      .distinct.pluck(:user_id).to_set

    recipients.select do |recipient|
      member_ids.include?(recipient.id) || owner?(subject, recipient)
    end
  end

  private

  def subject_project(subject)
    case subject
    when Project then subject
    when Scope, Task then subject.project
    end
  end

  # TaskPolicy#show? also grants visibility to the task's responsible user.
  def owner?(subject, recipient)
    subject.is_a?(Task) && subject.responsible_user_id == recipient.id
  end
end
