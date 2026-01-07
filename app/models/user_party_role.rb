class UserPartyRole < ApplicationRecord
  belongs_to :user
  belongs_to :party, polymorphic: true
end
