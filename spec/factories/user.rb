FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@company.com" }
    password  { "password" }
    confirmed_at { 1.day.ago }
    confirmation_sent_at { 1.day.ago }
    sequence(:confirmation_token) { |n| "token#{n}" }
  end
end
