class Notification < ApplicationRecord
  belongs_to :user

  scope :recent, -> { where("created_at > ?", 30.days.ago) }
  scope :unread, -> { where(read: false) }
end
