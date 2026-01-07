class Organization < ApplicationRecord
  include SoftDeletable
  has_many :user_party_roles, as: :party
  has_many :teams
  has_one :attachable, as: :attachable, dependent: :destroy
  has_many :attachments, through: :attachable
  has_one :notable, as: :notable, dependent: :destroy
  has_many :notes, through: :notable
  has_one :linkable, as: :linkable, dependent: :destroy
  has_many :links, through: :linkable
end
