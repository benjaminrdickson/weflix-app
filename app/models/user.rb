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


end
