class Favorite < ApplicationRecord

  belongs_to :relationship

  def details
    tmdb_type = content_type == "tv" ? "tv" : "movie"
    api_key = Rails.application.credentials.tmdb_api_key
    response = HTTP.get("https://api.themoviedb.org/3/#{tmdb_type}/#{api_movie_id}?api_key=#{api_key}&append_to_response=videos")
    data = response.parse(:json)

    video_key = data.dig("videos", "results", 0, "key")
    genre = data.dig("genres", 0, "name")

    if tmdb_type == "tv"
      {
        id: data["id"],
        title: data["name"],
        overview: data["overview"],
        poster_path: data["poster_path"],
        videos: video_key,
        release_date: data["first_air_date"],
        genre: genre,
        content_type: "tv"
      }
    else
      {
        id: data["id"],
        title: data["original_title"],
        overview: data["overview"],
        poster_path: data["poster_path"],
        videos: video_key,
        release_date: data["release_date"],
        genre: genre,
        content_type: "movie"
      }
    end
  end

end
