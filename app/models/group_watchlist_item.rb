class GroupWatchlistItem < ApplicationRecord
  include TmdbFetchable

  belongs_to :group

  validates :api_movie_id, uniqueness: { scope: [:group_id, :content_type] }
end
