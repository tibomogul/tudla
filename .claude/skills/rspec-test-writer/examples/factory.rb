# Example: FactoryBot factory template for Tudla. Save as spec/factories/<singular>.rb.
#
# WHY this template covers: block-form attributes, sequences for uniqueness,
# trait shortcuts (the user_party_role pattern), associations passed at call
# time, a transient attribute, and a callback. Tudla is factory-only — there
# are no lookup fixtures.

FactoryBot.define do
  factory :task do
    # ----- attributes (always block form) -----
    sequence(:name) { |n| "Task #{n}" }
    description      { "Description for #{name}" }

    # ----- associations -----
    # WHY: pass project/scope explicitly at call time in specs:
    #   create(:task, project: project, scope: scope)
    # Leave them off the factory so a bare create(:task) stays minimal, but be
    # aware task.organization/timezone walk project.team.organization.

    # ----- estimate fields (drive EstimateCacheable rollups) -----
    unassisted_estimate { nil }
    ai_assisted_estimate { nil }
    actual_manhours      { nil }

    # ----- traits -----
    # WHY: a task can only enter :in_progress when responsible_user and both
    # estimates are present (TaskStateMachine guard). This trait sets up a task
    # that satisfies the guard.
    trait :ready_to_start do
      association :responsible_user, factory: :user
      unassisted_estimate { 5 }
      ai_assisted_estimate { 3 }
    end

    trait :estimated do
      unassisted_estimate { 10 }
      ai_assisted_estimate { 5 }
      actual_manhours      { 3 }
    end

    # ----- transient attribute + callback -----
    transient do
      in_progress { false }
    end

    after(:create) do |task, evaluator|
      if evaluator.in_progress
        # WHY: never assign state directly — drive the Statesman machine so the
        # transition row and after_commit callback fire correctly.
        task.state_machine.transition_to!(:in_progress, user_id: task.responsible_user&.id)
      end
    end
  end

  # ----- trait-driven factory: UserPartyRole grants (the canonical pattern) -----
  factory :user_party_role_for_examples, class: "UserPartyRole" do
    user
    role { "member" }

    trait :org_admin do
      association :party, factory: :organization
      role { "admin" }
    end

    trait :team_member do
      association :party, factory: :team
      role { "member" }
    end
  end
end
