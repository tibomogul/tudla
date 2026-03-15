FactoryBot.define do
  factory :reportable do
    association :reportable, factory: :project
  end
end
