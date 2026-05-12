class Group < ApplicationRecord
  belongs_to :creator, class_name: "User"
  has_many :group_memberships, dependent: :destroy
  has_many :members, through: :group_memberships, source: :user
  has_many :group_invitations, dependent: :destroy
  has_many :group_likes, dependent: :destroy
  has_many :group_watchlist_items, dependent: :destroy

  validates :name, presence: true
end
