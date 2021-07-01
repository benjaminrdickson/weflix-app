class FavoriteSerializer < ActiveModel::Serializer
  attributes :id, :api_movie_id, :relationship_id

  # belongs_to :user
end
