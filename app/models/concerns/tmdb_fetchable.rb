module TmdbFetchable
  extend ActiveSupport::Concern

  def tmdb_details(region = "US")
    tmdb_type = content_type == "tv" ? "tv" : "movie"
    api_key = Rails.application.credentials.tmdb_api_key
    response = HTTP.get("https://api.themoviedb.org/3/#{tmdb_type}/#{api_movie_id}?api_key=#{api_key}&append_to_response=videos,watch/providers")
    data = response.parse(:json)

    videos = data.dig("videos", "results") || []
    youtube = videos.find { |v| v["site"] == "YouTube" && v["type"] == "Trailer" } ||
              videos.find { |v| v["site"] == "YouTube" }
    video_key = youtube&.dig("key")
    genre = data.dig("genres", 0, "name")

    region_data = data.dig("watch/providers", "results", region) || {}
    watch_providers = {
      flatrate: extract_tmdb_providers(region_data["flatrate"]),
      rent:     extract_tmdb_providers(region_data["rent"]),
      buy:      extract_tmdb_providers(region_data["buy"])
    }

    if tmdb_type == "tv"
      {
        id:              data["id"],
        title:           data["name"],
        overview:        data["overview"],
        poster_path:     data["poster_path"],
        videos:          video_key,
        release_date:    data["first_air_date"],
        genre:           genre,
        content_type:    "tv",
        watch_providers: watch_providers
      }
    else
      {
        id:              data["id"],
        title:           data["original_title"],
        overview:        data["overview"],
        poster_path:     data["poster_path"],
        videos:          video_key,
        release_date:    data["release_date"],
        genre:           genre,
        content_type:    "movie",
        watch_providers: watch_providers
      }
    end
  end

  private

  def extract_tmdb_providers(providers)
    return [] if providers.nil?
    providers.map { |p| { provider_id: p["provider_id"], provider_name: p["provider_name"], logo_path: p["logo_path"] } }
  end
end
