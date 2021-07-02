class RelationshipSerializer < ActiveModel::Serializer
  attributes :id, :confirmation

  belongs_to :sender
  belongs_to :recipient

end
