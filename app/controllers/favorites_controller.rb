class FavoritesController < ApplicationController

  def index
    # favorites = Favorite.all
    # render json: favorites 

    response = HTTP.get("https://api.themoviedb.org/3/discover/movie?api_key=#{Rails.application.credentials.tmdb_api_key}&language=en-US&sort_by=popularity.desc&include_adult=false&include_video=false&page=1&with_watch_monetization_types=flatrate")
    render json: response.parse(:json)


  end 

  # "https://api.themoviedb.org/3/discover/movie?api_key=#{Rails.application.credentials.tmdb_api_key}&language=en-US&sort_by=popularity.desc&include_adult=false&include_video=false&page=1&with_watch_monetization_types=flatrate"


#   def movie
#     response = HTTP.get("https://api.themoviedb.org/3/discover/movie?api_key=#{Rails.application.credentials.tmdb_api_key}&language=en-US&sort_by=popularity.desc&include_adult=false&include_video=false&page=1&with_watch_monetization_types=flatrate")
#     movie = response.parse(:json)
#     return{
#       id: movie["id"],
#       original_title: movie["original_title"],
#       overview: movie["overview"],
#       poster_path: movie["poster_path"],
#     }
#   end
# end




  def destroy 
    favorite = Favorite.find(params[:id])
    favorite.destroy 
    render json: {message: "Favorite successfully destroyed"}
  end 


end
