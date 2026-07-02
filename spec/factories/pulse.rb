FactoryBot.define do
  factory :pulse_subscribable, class: "Pulse::Subscribable" do
    association :subscribable, factory: :project

    # Pulse::Publishable already creates the container in the host model's
    # after_create; reuse it instead of violating the unique index.
    initialize_with { Pulse::Subscribable.find_or_initialize_by(subscribable: subscribable) }
  end

  factory :pulse_subscription, class: "Pulse::Subscription" do
    user
    association :subscribable, factory: :pulse_subscribable
  end

  factory :pulse_event, class: "Pulse::Event" do
    association :subscribable, factory: :pulse_subscribable
    user
    action { "project.updated" }
    actor_type { "user" }
    metadata { { "subject_name" => "Project1", "actor_name" => "User1" } }
  end

  factory :pulse_notification, class: "Pulse::Notification" do
    user
    association :event, factory: :pulse_event
  end
end
