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
  end
end
