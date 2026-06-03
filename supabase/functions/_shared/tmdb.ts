const TMDB_BASE = 'https://api.themoviedb.org/3';

function apiKey(): string {
  return Deno.env.get('TMDB_API_KEY') ?? '';
}

// Replicates MoviesController#detail.
// Returns raw TMDB response with content_type added and TV title/release_date normalized.
// The full videos object (including results array) is preserved so DetailModal.js
// can find the trailer key client-side.
export async function fetchRawDetail(id: number, type: 'movie' | 'tv') {
  const url = `${TMDB_BASE}/${type}/${id}?api_key=${apiKey()}&append_to_response=videos,genres`;
  const res = await fetch(url);
  const data = await res.json();

  if (type === 'tv') {
    return {
      ...data,
      title:        data.name,
      release_date: data.first_air_date,
      content_type: 'tv',
    };
  }
  return { ...data, content_type: 'movie' };
}

// Replicates TmdbFetchable#tmdb_details exactly.
// Returns processed data: video_key string, first genre name, structured watch_providers.
// Used by favorites and group watchlist enrichment.
export async function fetchProcessedDetail(id: number, type: 'movie' | 'tv', region = 'US') {
  const url = `${TMDB_BASE}/${type}/${id}?api_key=${apiKey()}&append_to_response=videos,watch/providers`;
  const res = await fetch(url);
  const data = await res.json();

  const videos: any[] = data?.videos?.results ?? [];
  const youtube =
    videos.find((v) => v.site === 'YouTube' && v.type === 'Trailer') ??
    videos.find((v) => v.site === 'YouTube');
  const videoKey: string | null = youtube?.key ?? null;

  const genre: string | null = data?.genres?.[0]?.name ?? null;

  const regionData = data?.['watch/providers']?.results?.[region] ?? {};
  const watchProviders = {
    flatrate: extractProviders(regionData.flatrate),
    rent:     extractProviders(regionData.rent),
    buy:      extractProviders(regionData.buy),
  };

  if (type === 'tv') {
    return {
      id:              data.id,
      title:           data.name,
      overview:        data.overview,
      poster_path:     data.poster_path,
      videos:          videoKey,
      release_date:    data.first_air_date,
      genre,
      content_type:    'tv',
      watch_providers: watchProviders,
    };
  }
  return {
    id:              data.id,
    title:           data.original_title,
    overview:        data.overview,
    poster_path:     data.poster_path,
    videos:          videoKey,
    release_date:    data.release_date,
    genre,
    content_type:    'movie',
    watch_providers: watchProviders,
  };
}

function extractProviders(providers: any[] | null | undefined) {
  if (!providers) return [];
  return providers.map((p) => ({
    provider_id:   p.provider_id,
    provider_name: p.provider_name,
    logo_path:     p.logo_path,
  }));
}
