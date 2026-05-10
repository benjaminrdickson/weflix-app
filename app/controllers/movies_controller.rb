class MoviesController < ApplicationController
  before_action :authenticate_user

  # GET /movies/random — kept for backwards compatibility
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

  # GET /browse
  def browse
    api_key   = Rails.application.credentials.tmdb_api_key
    page      = (params[:page] || 1).to_i.clamp(1, 500)
    query     = params[:query].to_s.strip
    genre_id  = params[:genre_id].presence
    raw_type  = params[:content_type].presence || "movie"
    types     = raw_type == "both" ? ["movie", "tv"] : [raw_type == "tv" ? "tv" : "movie"]

    excluded_ids = excluded_content_ids(types)

    results = types.flat_map do |tmdb_type|
      fetch_tmdb_page(api_key, tmdb_type, page, query, genre_id)
        .reject { |item| excluded_ids[tmdb_type].include?(item["id"]) }
        .map    { |item| normalize_browse_item(item, tmdb_type) }
    end

    results = results.sort_by { |r| -(r["popularity"] || 0) } if raw_type == "both"

    render json: { results: results, page: page }
  end

  # GET /browse/:id — full detail for the modal (includes videos)
  def detail
    api_key     = Rails.application.credentials.tmdb_api_key
    tmdb_type   = params[:content_type] == "tv" ? "tv" : "movie"
    detail_url  = "https://api.themoviedb.org/3/#{tmdb_type}/#{params[:id]}?api_key=#{api_key}&append_to_response=videos,genres"
    detail      = HTTP.get(detail_url).parse(:json)
    render json: normalize_content(detail, tmdb_type)
  end

  private

  def fetch_tmdb_page(api_key, tmdb_type, page, query, genre_id)
    if query.present?
      url = "https://api.themoviedb.org/3/search/#{tmdb_type}?api_key=#{api_key}&language=en-US&include_adult=false&page=#{page}&query=#{CGI.escape(query)}"
    else
      url = "https://api.themoviedb.org/3/discover/#{tmdb_type}?api_key=#{api_key}&language=en-US&sort_by=popularity.desc&include_adult=false&page=#{page}"
      url += "&with_genres=#{genre_id}" if genre_id
    end
    HTTP.get(url).parse(:json)["results"] || []
  end

  def excluded_content_ids(types)
    types.each_with_object({}) do |tmdb_type, hash|
      liked  = current_user.likes.where(content_type: tmdb_type).pluck(:api_movie_id).to_set
      passed = current_user.passes.where(content_type: tmdb_type).pluck(:api_movie_id).to_set
      hash[tmdb_type] = liked | passed
    end
  end

  def normalize_browse_item(item, tmdb_type)
    {
      "id"           => item["id"],
      "title"        => tmdb_type == "tv" ? item["name"] : item["title"],
      "poster_path"  => item["poster_path"],
      "overview"     => item["overview"],
      "release_date" => tmdb_type == "tv" ? item["first_air_date"] : item["release_date"],
      "genre_ids"    => item["genre_ids"] || [],
      "popularity"   => item["popularity"],
      "content_type" => tmdb_type,
    }
  end

  def normalize_content(detail, tmdb_type)
    if tmdb_type == "tv"
      detail.merge(
        "title"        => detail["name"],
        "release_date" => detail["first_air_date"],
        "content_type" => "tv"
      )
    else
      detail.merge("content_type" => "movie")
    end
  end

  def resolve_content_type(param)
    case param
    when "tv"   then "tv"
    when "both" then ["movie", "tv"].sample
    else "movie"
    end
  end
end
