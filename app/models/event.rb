class Event < ApplicationRecord
  belongs_to :subscribable
  belongs_to :user
  validates :action, presence: true
  validates :metadata, presence: true
end
