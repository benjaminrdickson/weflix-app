class GenresController < ApplicationController
  before_action :authenticate_user

  def index
    api_key = Rails.application.credentials.tmdb_api_key
    content_type = params[:content_type]

    types = content_type == "tv" ? ["tv"] : content_type == "both" ? ["movie", "tv"] : ["movie"]

    genres = types.flat_map do |type|
      url = "https://api.themoviedb.org/3/genre/#{type}/list?api_key=#{api_key}&language=en-US"
      HTTP.get(url).parse(:json)["genres"] || []
    end

    unique_genres = genres.uniq { |g| g["id"] }.sort_by { |g| g["name"] }
    render json: unique_genres
  end
end
