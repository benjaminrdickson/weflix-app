class UserSerializer < ActiveModel::Serializer
  attributes :id, :name, :username, :image_url, :email

  
  has_one :partner


end
