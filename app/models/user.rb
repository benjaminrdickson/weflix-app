class User < ApplicationRecord

  has_secure_password
  has_one_attached :profile_picture
  validates :email, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true


  def relationship
    Relationship.find_by("sender_id = ? OR recipient_id = ? ", id, id )
  end 

  def partner
    rel = relationship
    return nil unless rel
    rel.sender_id == id ? rel.recipient : rel.sender
  end




  has_many :likes
  has_many :passes
  has_many :sent_friendships, class_name: "Friendship", foreign_key: :sender_id, dependent: :destroy
  has_many :received_friendships, class_name: "Friendship", foreign_key: :recipient_id, dependent: :destroy
  has_many :group_memberships, dependent: :destroy
  has_many :groups, through: :group_memberships
  has_many :created_groups, class_name: "Group", foreign_key: :creator_id, dependent: :destroy
  has_many :group_likes, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_one  :push_token, dependent: :destroy
  has_one  :notification_preference, dependent: :destroy


end
