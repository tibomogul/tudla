FactoryBot.define do
  factory :pulse_subscribable, class: "Pulse::Subscribable" do
    association :subscribable, factory: :project
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
