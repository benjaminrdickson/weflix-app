class MoviesController < ApplicationController

  

  def show
    page = rand(1...20)
    response = HTTP.get("https://api.themoviedb.org/3/discover/movie?api_key=#{Rails.application.credentials.tmdb_api_key}&language=en-US&sort_by=popularity.desc&include_adult=false&include_video=false&page=#{page}&with_watch_monetization_types=flatrate")
    movies = response.parse(:json)["results"]
    # pick a random sample from movies
    # if that random sample is already liked, pick another
    # if it's not liked, render it
    while true
      random_movie = movies.sample
      unless current_user.likes.find_by({api_movie_id: random_movie["id"]})
        render json: random_movie
        break
      end
    end
    
  end 


  
  



end
