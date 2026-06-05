class PitchCoAuthor < ApplicationRecord
  has_paper_trail

  belongs_to :pitch
  belongs_to :user

  validates :user_id, uniqueness: { scope: :pitch_id }
end
