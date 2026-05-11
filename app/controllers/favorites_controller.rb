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
    content = favorite.details
    providers = fetch_watch_providers(favorite.api_movie_id, favorite.content_type, region)
    content.merge(
      favorite_id: favorite.id,
      watch_providers: providers
    )
  end

  def fetch_watch_providers(api_id, content_type, region)
    tmdb_type = content_type == "tv" ? "tv" : "movie"
    api_key = Rails.application.credentials.tmdb_api_key
    url = "https://api.themoviedb.org/3/#{tmdb_type}/#{api_id}/watch/providers?api_key=#{api_key}"
    response = HTTP.get(url).parse(:json)
    region_data = response.dig("results", region) || {}

    {
      flatrate: extract_providers(region_data["flatrate"]),
      rent: extract_providers(region_data["rent"]),
      buy: extract_providers(region_data["buy"])
    }
  end

  def extract_providers(providers)
    return [] if providers.nil?
    providers.map do |p|
      {
        provider_id: p["provider_id"],
        provider_name: p["provider_name"],
        logo_path: p["logo_path"]
      }
    end
  end

end
