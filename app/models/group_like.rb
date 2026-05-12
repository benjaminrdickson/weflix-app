class GroupLike < ApplicationRecord
  belongs_to :group
  belongs_to :user

  validates :api_movie_id, uniqueness: { scope: [:group_id, :user_id, :content_type] }
end
