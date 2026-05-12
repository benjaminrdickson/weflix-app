class NotificationsController < ApplicationController
  before_action :authenticate_user

  def index
    current_user.notifications.where("created_at <= ?", 30.days.ago).delete_all
    notifications = current_user.notifications.recent.order(created_at: :desc)
    render json: notifications.map { |n| serialize(n) }
  end

  def update
    notif = current_user.notifications.find_by(id: params[:id])
    return render json: { error: "Not found" }, status: :not_found unless notif
    notif.update!(read: true)
    render json: serialize(notif)
  end

  def mark_all_read
    current_user.notifications.recent.unread.update_all(read: true)
    render json: { message: "All notifications marked as read" }
  end

  def clear_all
    current_user.notifications.delete_all
    render json: { message: "All notifications cleared" }
  end

  private

  def serialize(n)
    {
      id:                n.id,
      notification_type: n.notification_type,
      message:           n.message,
      read:              n.read,
      context:           n.context,
      created_at:        n.created_at,
    }
  end
end
