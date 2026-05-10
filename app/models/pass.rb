class Pass < ApplicationRecord
  belongs_to :user
  validates :api_movie_id, uniqueness: { scope: [:user_id, :content_type] }
end
