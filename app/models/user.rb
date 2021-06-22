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

  # user1 = User.create(
  #   name: "Dani"
  # )

  # user2 = User.create(
  #   name: "Ryan"
  # )

  # relationship = Relationship.create(
  #   sender_id: 1
  #   recipient_id: 2
  #   confirmation: true
  # )

  # has_one :relationship
  # has_one :partner 

  has_many :likes 


end
