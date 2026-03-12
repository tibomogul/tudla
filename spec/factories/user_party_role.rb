FactoryBot.define do
  factory :user_party_role do
    user
    role { "member" }

    trait :org_admin do
      association :party, factory: :organization
      role { "admin" }
    end

    trait :org_member do
      association :party, factory: :organization
      role { "member" }
    end

    trait :team_admin do
      association :party, factory: :team
      role { "admin" }
    end

    trait :team_member do
      association :party, factory: :team
      role { "member" }
    end
  end
end
