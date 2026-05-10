class PassesController < ApplicationController
  before_action :authenticate_user

  def create
    content_type = params[:content_type].presence || "movie"
    api_id = params[:api_movie_id].to_i

    pass = Pass.find_or_initialize_by(
      user_id: current_user.id,
      api_movie_id: api_id,
      content_type: content_type
    )
    if pass.save
      render json: pass
    else
      render json: { errors: pass.errors.full_messages }, status: :bad_request
    end
  end
end
