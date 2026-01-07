class Subscribable < ApplicationRecord
  delegated_type :subscribable, types: %w[Project Scope Task]

  has_many :subscriptions
  has_many :users, through: :subscriptions

  has_many :events
  has_many :notifications, through: :events
end
