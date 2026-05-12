class NotificationService
  PREF_MAP = {
    "friend_request"              => "friend_requests",
    "friend_request_accepted"     => "friend_request_accepted",
    "partner_invitation"          => "partner_invitations",
    "partner_invitation_approved" => "partner_invitations",
    "partner_watchlist_match"     => "partner_watchlist_matches",
    "group_invitation"            => "group_invitations",
    "group_invitation_approved"   => "group_invitations",
    "group_watchlist_match"       => "group_watchlist_matches",
    "group_join_request"          => "group_join_requests",
  }.freeze

  def self.deliver(users:, type:, message:, context: nil)
    Array(users).each do |user|
      prefs = NotificationPreference.for(user)
      pref_col = PREF_MAP[type]
      next unless pref_col.nil? || prefs.public_send(pref_col)

      notif = handle_grouping(user, type, message, context)
      send_push(user, notif.message) if notif
    end
  end

  private

  def self.handle_grouping(user, type, message, context)
    if watchlist_type?(type) && context.present?
      existing = user.notifications
                     .unread
                     .where(notification_type: type, context: context)
                     .where("created_at > ?", 60.seconds.ago)
                     .order(:created_at)

      if existing.any?
        count = existing.count + 1
        grouped_message = grouped_message(type, context, count)
        existing.update_all(message: grouped_message, updated_at: Time.current)
        return existing.first.tap { |n| n.message = grouped_message }
      end
    end

    user.notifications.create!(notification_type: type, message: message, context: context)
  end

  def self.send_push(user, message)
    token = user.push_token&.token
    return unless token&.start_with?("ExponentPushToken")

    HTTP.post(
      "https://exp.host/--/expo-push-notification/api/v2/push/send",
      json: { to: token, body: message, sound: "default", badge: unread_count(user) }
    )
  rescue StandardError
    # push failure must never raise — in-app notification already saved
  end

  def self.unread_count(user)
    user.notifications.recent.unread.count
  end

  def self.watchlist_type?(type)
    type == "partner_watchlist_match" || type == "group_watchlist_match"
  end

  def self.grouped_message(type, context, count)
    if type == "partner_watchlist_match"
      "#{count} new matches on your Partner watchlist!"
    else
      group_name = Group.find_by(id: context.to_s.sub("group_", ""))&.name || "your group"
      "#{count} new titles added to #{group_name}!"
    end
  end
end
