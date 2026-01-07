FactoryBot.define do
  factory :user do
    email { "user@company.com" }
    password  { "password" }
    confirmed_at { 1.day.ago }
    confirmation_sent_at { 1.day.ago }
    confirmation_token { "token" }
  end
end
