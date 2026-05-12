class GroupLikesController < ApplicationController
  before_action :authenticate_user

  def create
    group = Group.find_by(id: params[:group_id])
    return render json: { error: "Not found" }, status: :not_found unless group&.members&.exists?(id: current_user.id)

    api_id       = params[:api_movie_id].to_i
    content_type = params[:content_type].presence || "movie"

    group_like = GroupLike.find_or_initialize_by(
      group_id:     group.id,
      user_id:      current_user.id,
      api_movie_id: api_id,
      content_type: content_type
    )
    return render json: { message: "Already liked" } if group_like.persisted?

    if group_like.save
      check_threshold(group, api_id, content_type)
      render json: { group_like_id: group_like.id }, status: :created
    else
      render json: { errors: group_like.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def check_threshold(group, api_id, content_type)
    member_count = group.group_memberships.count
    likes_count  = GroupLike.where(group_id: group.id, api_movie_id: api_id, content_type: content_type).count
    return unless likes_count.to_f / member_count > 0.5

    item, created = GroupWatchlistItem.find_or_create_by(
      group_id:     group.id,
      api_movie_id: api_id,
      content_type: content_type
    ).then { |i| [i, i.previously_new_record?] }

    if created
      members = group.members
      NotificationService.deliver(
        users:   members,
        type:    "group_watchlist_match",
        message: "A new title was added to #{group.name}!",
        context: "group_#{group.id}"
      )
    end
  end
end
