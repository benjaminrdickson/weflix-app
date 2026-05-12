class FriendshipsController < ApplicationController
  before_action :authenticate_user

  def index
    confirmed = current_user.sent_friendships.where(confirmed: true).includes(:recipient) +
                current_user.received_friendships.where(confirmed: true).includes(:sender)

    pending = current_user.received_friendships.where(confirmed: false).includes(:sender)

    render json: {
      friends: confirmed.map { |f|
        friend = f.sender_id == current_user.id ? f.recipient : f.sender
        user_json(friend).merge(friendship_id: f.id)
      },
      pending_requests: pending.map { |f|
        user_json(f.sender).merge(friendship_id: f.id)
      }
    }
  end

  def create
    recipient = User.find_by(username: params[:username])
    return render json: { error: "User not found" }, status: :not_found unless recipient
    return render json: { error: "Cannot send a friend request to yourself" }, status: :unprocessable_entity if recipient.id == current_user.id

    existing = Friendship.find_by(sender_id: current_user.id, recipient_id: recipient.id) ||
               Friendship.find_by(sender_id: recipient.id, recipient_id: current_user.id)
    return render json: { error: "Friendship already exists" }, status: :unprocessable_entity if existing

    friendship = Friendship.new(sender: current_user, recipient: recipient)
    if friendship.save
      NotificationService.deliver(
        users:   recipient,
        type:    "friend_request",
        message: "#{current_user.name} sent you a friend request"
      )
      render json: { friendship_id: friendship.id, recipient: user_json(recipient) }, status: :created
    else
      render json: { errors: friendship.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    friendship = Friendship.find(params[:id])
    return render json: { error: "Unauthorized" }, status: :unauthorized unless friendship.recipient == current_user
    friendship.confirmed = true
    if friendship.save
      NotificationService.deliver(
        users:   friendship.sender,
        type:    "friend_request_accepted",
        message: "#{current_user.name} accepted your friend request"
      )
      render json: { friendship_id: friendship.id, sender: user_json(friendship.sender) }
    else
      render json: { errors: friendship.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    friendship = Friendship.find(params[:id])
    return render json: { error: "Unauthorized" }, status: :unauthorized unless friendship.sender_id == current_user.id || friendship.recipient_id == current_user.id
    friendship.destroy
    render json: { message: "Friendship removed" }
  end

  private

  def user_json(user)
    {
      id: user.id,
      name: user.name,
      username: user.username,
      image_url: user.profile_picture.attached? ? user.profile_picture.blob.url : user.image_url
    }
  end
end
