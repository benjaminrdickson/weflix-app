class MoviesController < ApplicationController

  # has_many :likes
  # has_many :favorites

  def show
    response = HTTP.get("https://api.themoviedb.org/3/discover/movie?api_key=#{Rails.application.credentials.tmdb_api_key}&language=en-US&sort_by=popularity.desc&include_adult=false&include_video=false&page=1&with_watch_monetization_types=flatrate")
    random_movie = response.parse(:json)["results"].sample
    
    render json: random_movie
    
  end 
  



end
