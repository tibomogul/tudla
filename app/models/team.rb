class Team < ApplicationRecord
  include SoftDeletable
  belongs_to :organization
  has_many :projects
  has_many :user_party_roles, as: :party
  has_many :users, through: :user_party_roles
  has_one :reportable, as: :reportable, dependent: :destroy
  has_many :reports, through: :reportable
  has_one :attachable, as: :attachable, dependent: :destroy
  has_many :attachments, through: :attachable
  has_one :notable, as: :notable, dependent: :destroy
  has_many :notes, through: :notable
  has_one :linkable, as: :linkable, dependent: :destroy
  has_many :links, through: :linkable
end
