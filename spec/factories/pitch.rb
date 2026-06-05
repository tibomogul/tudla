FactoryBot.define do
  factory :pitch do
    title { "Pitch 1" }
    problem { "Description of the problem" }
    appetite { 6 }
    solution { "Proposed solution" }
    rabbit_holes { "Known risks" }
    no_gos { "Out of scope" }
    association :user
    association :organization

    trait :with_co_authors do
      transient do
        co_author_count { 1 }
      end

      after(:create) do |pitch, evaluator|
        evaluator.co_author_count.times do
          user = create(:user)
          UserPartyRole.create!(user: user, party: pitch.organization, role: "member")
          pitch.co_authors << user
        end
      end
    end
  end
end
