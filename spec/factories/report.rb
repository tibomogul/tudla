FactoryBot.define do
  factory :report do
    content { "Report content" }
    association :user
    association :reportable
  end
end
