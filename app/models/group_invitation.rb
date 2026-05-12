class GroupInvitation < ApplicationRecord
  belongs_to :group
  belongs_to :inviter, class_name: "User"
  belongs_to :invitee, class_name: "User"

  validates :invitee_id, uniqueness: { scope: :group_id }
  validates :status, inclusion: { in: %w[pending approved rejected] }
end
