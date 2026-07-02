module Pulse
  # Producer pillar entry point. Creates the Pulse::Event row synchronously —
  # when called from model callbacks this happens inside the domain
  # transaction (transactional outbox), and Pulse::Event enqueues the fan-out
  # job only on commit.
  class Publisher
    def self.publish(subject:, action:, metadata: {}, user: :current, actor_type: nil, actor_label: nil)
      actor_user = user == :current ? Pulse::Current.user : user
      resolved_type = actor_type ||
        (actor_user == Pulse::Current.user ? Pulse::Current.resolved_actor_type : "user")
      resolved_label = actor_label || Pulse::Current.actor_label

      Pulse::Event.create!(
        subscribable: Pulse::Subscribable.find_or_create_by!(subscribable: subject),
        user: actor_user,
        actor_type: actor_user ? resolved_type : "system",
        actor_label: resolved_label,
        action: action,
        metadata: default_metadata(subject, actor_user, resolved_label).merge(metadata.stringify_keys)
      )
    end

    # Denormalized display data captured at publish time so notification text
    # survives later rename or deletion of the subject.
    def self.default_metadata(subject, actor_user, actor_label)
      {
        "subject_type" => subject.class.name,
        "subject_id" => subject.id,
        "subject_name" => subject.try(:name),
        "actor_name" => actor_user&.display_name || actor_label.presence || "System"
      }
    end
  end
end
