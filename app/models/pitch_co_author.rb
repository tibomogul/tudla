class PitchCoAuthor < ApplicationRecord
  has_paper_trail

  belongs_to :pitch
  belongs_to :user

  validates :user_id, uniqueness: { scope: :pitch_id }

  # Drops the user's co-author rows on pitches in organization_id WHEN the user
  # is no longer a member of that org — co-authorship requires current
  # membership. No-ops while membership stands. Per-row destroy keeps the
  # PaperTrail audit. Callers MUST bust the user's org caches first so the
  # membership recheck recomputes fresh. Shared by every revocation path
  # (role removal, team soft-delete, user soft-delete).
  #
  # Whodunnit: this prune is a CONSEQUENCE of a triggering action (a role being
  # removed, a team or user being archived). We intentionally do NOT set a
  # synthetic actor — that would clobber the real one. When the triggering
  # action runs through a controller, PaperTrail's request context already
  # carries the responsible admin, and these revocation rows are attributed to
  # them. The audit is actor-less only when the trigger originates outside a
  # request (console / rake / job), where no user is genuinely responsible —
  # consistent with PaperTrail behaviour elsewhere in the app.
  def self.prune_orphaned_for(user, organization_id)
    return if user.blank? || organization_id.blank?
    return if user.member_organization_ids.include?(organization_id)

    joins(:pitch)
      .where(user_id: user.id, pitches: { organization_id: organization_id })
      .find_each(&:destroy)
  end
end
