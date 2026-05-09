class Favorite < ApplicationRecord

  belongs_to :relationship 


  def movie
    response = HTTP.get("https://api.themoviedb.org/3/movie/#{api_movie_id}?api_key=#{Rails.application.credentials.tmdb_api_key}&append_to_response=videos")
    movie = response.parse(:json)
    video_key = movie["videos"]["results"].any? ? movie["videos"]["results"][0]["key"] : nil
    return{
      id: movie["id"],
      original_title: movie["original_title"],
      overview: movie["overview"],
      poster_path: movie["poster_path"],
      videos: video_key,
      release_date: movie["release_date"],
      genre: movie["genres"][0]["name"]
    }
  end

  

end
