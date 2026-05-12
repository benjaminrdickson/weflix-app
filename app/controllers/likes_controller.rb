class LikesController < ApplicationController

  before_action :authenticate_user

  def create
    content_type = params[:content_type].presence || "movie"
    api_id = params[:api_movie_id]

    partner = current_user.partner
    partner_like = partner && Like.find_by(user_id: partner.id, api_movie_id: api_id, content_type: content_type)

    if partner_like
      favorite = Favorite.new(
        relationship_id: current_user.relationship.id,
        api_movie_id: api_id,
        content_type: content_type
      )
      if favorite.save
        partner_like.destroy
        [current_user, partner].each do |user|
          NotificationService.deliver(
            users:   user,
            type:    "partner_watchlist_match",
            message: "You and #{user == current_user ? partner.name : current_user.name} matched! Check your Partner watchlist.",
            context: "partner"
          )
        end
        render json: favorite
      else
        render json: { errors: favorite.errors.full_messages }, status: :bad_request
      end
    else
      like = Like.new(
        user_id: current_user.id,
        api_movie_id: api_id,
        content_type: content_type
      )
      if like.save
        render json: like
      else
        render json: { errors: like.errors.full_messages }, status: :bad_request
      end
    end
  end
      



end

# when user hits like button, check to see if partner has liked as well. If partner also has liked, then that like moves to favorties. If partner has not also liked, like is created for current user.
# find user_id, and api_movie_id