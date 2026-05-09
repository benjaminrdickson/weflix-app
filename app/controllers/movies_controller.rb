class MoviesController < ApplicationController

  before_action :authenticate_user

  def show
    page = rand(1...20)
    response = HTTP.get("https://api.themoviedb.org/3/discover/movie?api_key=#{Rails.application.credentials.tmdb_api_key}&language=en-US&sort_by=popularity.desc&include_adult=false&include_video=false&page=#{page}&with_watch_monetization_types=flatrate")
    movies = response.parse(:json)["results"]

    liked_ids = current_user.likes.pluck(:api_movie_id).to_set
    candidate = movies.reject { |m| liked_ids.include?(m["id"]) }.sample

    if candidate.nil?
      render json: { error: "No new movies available" }, status: :not_found
      return
    end

    movie_detail = HTTP.get("https://api.themoviedb.org/3/movie/#{candidate["id"]}?api_key=#{Rails.application.credentials.tmdb_api_key}&append_to_response=videos")
    render json: movie_detail.parse(:json)
  end


  
  



end
