class RelationshipSerializer < ActiveModel::Serializer
  attributes :id, :sender, :recipient
end
