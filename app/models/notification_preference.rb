class NotificationPreference < ApplicationRecord
  belongs_to :user

  PREFERENCE_COLUMNS = %w[
    friend_requests
    friend_request_accepted
    partner_invitations
    partner_watchlist_matches
    group_invitations
    group_watchlist_matches
    group_join_requests
  ].freeze

  def self.for(user)
    user.notification_preference || new(
      PREFERENCE_COLUMNS.each_with_object({}) { |col, h| h[col] = true }
    )
  end
end
