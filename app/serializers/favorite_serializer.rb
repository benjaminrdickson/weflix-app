class FavoriteSerializer < ActiveModel::Serializer
  attributes :id, :relationship_id

  belongs_to :movie

  
end
