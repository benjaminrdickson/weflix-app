class Friendship < ApplicationRecord
  belongs_to :sender, class_name: "User"
  belongs_to :recipient, class_name: "User"

  validates :recipient_id, uniqueness: { scope: :sender_id }
  validate :not_self

  private

  def not_self
    errors.add(:recipient_id, "can't befriend yourself") if sender_id == recipient_id
  end
end
