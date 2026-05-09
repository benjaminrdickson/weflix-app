class MoviesController < ApplicationController

  before_action :authenticate_user

  def show
    content_type = resolve_content_type(params[:content_type])
    page = rand(1...20)
    api_key = Rails.application.credentials.tmdb_api_key

    tmdb_type = content_type == "tv" ? "tv" : "movie"
    discover_url = "https://api.themoviedb.org/3/discover/#{tmdb_type}?api_key=#{api_key}&language=en-US&sort_by=popularity.desc&include_adult=false&page=#{page}&with_watch_monetization_types=flatrate"
    results = HTTP.get(discover_url).parse(:json)["results"]

    liked_ids = current_user.likes.where(content_type: tmdb_type).pluck(:api_movie_id).to_set
    candidate = results.reject { |m| liked_ids.include?(m["id"]) }.sample

    if candidate.nil?
      render json: { error: "No new content available" }, status: :not_found
      return
    end

    detail_url = "https://api.themoviedb.org/3/#{tmdb_type}/#{candidate["id"]}?api_key=#{api_key}&append_to_response=videos"
    detail = HTTP.get(detail_url).parse(:json)

    render json: normalize_content(detail, tmdb_type)
  end

  private

  def resolve_content_type(param)
    case param
    when "tv" then "tv"
    when "both" then ["movie", "tv"].sample
    else "movie"
    end
  end

  def normalize_content(detail, tmdb_type)
    if tmdb_type == "tv"
      detail.merge(
        "title" => detail["name"],
        "release_date" => detail["first_air_date"],
        "content_type" => "tv"
      )
    else
      detail.merge("content_type" => "movie")
    end
  end


  
  



end
