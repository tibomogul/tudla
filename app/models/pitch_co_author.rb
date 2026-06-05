class PitchCoAuthor < ApplicationRecord
  belongs_to :pitch
  belongs_to :user

  validates :user_id, uniqueness: { scope: :pitch_id }
end
