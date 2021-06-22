class LikesController < ApplicationController

  before_action :authenticate_user

  def create 
    partner_like = Like.find_by(user_id: current_user.partner.id, api_movie_id: params[:api_movie_id])
    if partner_like
      favorite = Favorite.new(
        relationship_id: current_user.relationship.id,
        api_movie_id: params[:api_movie_id]
      )
      if favorite.save
        render json: favorite
      else
        render json: {errors: favorite.errors.full_messages }, status: :bad_request
      end 
    else
      like = Like.new(
        user_id: current_user.id, 
        api_movie_id: params[:api_movie_id],
      )
      if like.save
        render json: like
      else
        render json: {errors: like.errors.full_messages }, status: :bad_request
      end 
    end 
    
  end 
      



end

# when user hits like button, check to see if partner has liked as well. If partner also has liked, then that like moves to favorties. If partner has not also liked, like is created for current user.
# find user_id, and api_movie_id