class UserSerializer < ActiveModel::Serializer
  attributes :id, :name, :username, :image, :email

  has_many :favorites
  has_one :partner


end
