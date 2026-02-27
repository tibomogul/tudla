FactoryBot.define do
  factory :cycle do
    name { "Cycle 1" }
    start_date { Date.current }
    end_date { Date.current + 8.weeks }
    association :organization
  end
end
