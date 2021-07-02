class Favorite < ApplicationRecord

  belongs_to :relationship 


  def movie
    response = HTTP.get("https://api.themoviedb.org/3/movie/#{api_movie_id}?api_key=#{Rails.application.credentials.tmdb_api_key}")
    movie = response.parse(:json)
    return{
      id: movie["id"],
      original_title: movie["original_title"],
      overview: movie["overview"],
      poster_path: movie["poster_path"],
    }
  end

  

end
