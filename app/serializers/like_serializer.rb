class LikeSerializer < ActiveModel::Serializer
  attributes :id, :user_id

  belongs_to :movie
  belongs_to :user

  

  


  
end
