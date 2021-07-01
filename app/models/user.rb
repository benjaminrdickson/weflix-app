class User < ApplicationRecord

  has_secure_password
  validates :email, presence: true, uniqueness: true


  def relationship
    Relationship.where(confirmation: true).find_by("sender_id = ? OR recipient_id = ? ", id, id )
  end 

  def partner 
    if relationship
      if relationship.sender_id == id
        return relationship.recipient
      else
        return relationship.sender 
      end 
    end 
    nil
  end

  def approved_relationship
    Relationship.where("sender_id = ? OR recipient_id = ?", id, id).where(confirmed: true)
  end


  

  has_one :relationship
  has_one :partner 

  has_many :likes 
  has_many :favorites


end
