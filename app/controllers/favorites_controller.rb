class FavoritesController < ApplicationController

  before_action :authenticate_user

  def index
    unless current_user.relationship
      render json: []
      return
    end
    region = params[:region].presence || "US"
    favorites = current_user.relationship.favorites
    render json: favorites.map { |f| build_favorite_json(f, region) }
  end

  def destroy
    favorite = Favorite.find(params[:id])
    return render json: { error: "Unauthorized" }, status: :unauthorized unless current_user.relationship&.id == favorite.relationship_id
    favorite.destroy
    render json: { message: "Favorite successfully destroyed" }
  end

  private

  def build_favorite_json(favorite, region)
    favorite.details(region).merge(favorite_id: favorite.id)
  end

end
