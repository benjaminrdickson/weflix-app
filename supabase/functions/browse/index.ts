import { corsHeaders } from '../_shared/cors.ts';
import { getUser, getAdminClient } from '../_shared/auth.ts';
import { fetchRawDetail } from '../_shared/tmdb.ts';

const TMDB_BASE = 'https://api.themoviedb.org/3';
const tmdbKey = () => Deno.env.get('TMDB_API_KEY') ?? '';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  const user = await getUser(req);
  if (!user) {
    return json({ error: 'Unauthorized' }, 401);
  }

  try {
    const url = new URL(req.url);

    // Detect /browse/:id — path ends with a numeric segment after "browse"
    const idMatch = url.pathname.match(/\/browse\/(\d+)/);
    if (idMatch) {
      return await handleDetail(parseInt(idMatch[1], 10), url.searchParams);
    }
    return await handleBrowse(user.id, url.searchParams);
  } catch (err) {
    console.error(err);
    return json({ error: 'Internal error' }, 500);
  }
});

// Replicates MoviesController#detail exactly.
// Returns raw TMDB response with content_type + normalized TV title/release_date.
// DetailModal.js reads detail?.videos?.results client-side to find the trailer key.
async function handleDetail(id: number, params: URLSearchParams): Promise<Response> {
  const type = params.get('content_type') === 'tv' ? 'tv' : 'movie';
  const data = await fetchRawDetail(id, type);
  return json(data);
}

// Replicates MoviesController#browse exactly.
async function handleBrowse(userId: string, params: URLSearchParams): Promise<Response> {
  const rawType         = params.get('content_type') || 'movie';
  const page            = Math.min(Math.max(parseInt(params.get('page') || '1', 10), 1), 500);
  const query           = params.get('query')?.trim() || '';
  const genreId         = params.get('genre_id') || null;
  const context         = params.get('context') || 'partner';
  const region          = params.get('region') || 'US';
  const watchProviderId = query ? null : (params.get('watch_provider_id') || null);

  const types: Array<'movie' | 'tv'> =
    rawType === 'both' ? ['movie', 'tv'] : [rawType === 'tv' ? 'tv' : 'movie'];

  const excludedIds = await getExcludedIds(userId, types, context);

  const pages = await Promise.all(
    types.map((tmdbType) =>
      fetchTmdbPage(tmdbType, page, query, genreId, watchProviderId, region).then((items) =>
        items
          .filter((item: any) => !excludedIds[tmdbType].has(item.id))
          .map((item: any) => normalizeBrowseItem(item, tmdbType))
      )
    )
  );

  let results = pages.flat();

  // When browsing "both", merge results sorted by popularity descending
  if (rawType === 'both') {
    results = results.sort((a: any, b: any) => (b.popularity || 0) - (a.popularity || 0));
  }

  return json({ results, page });
}

// Replicates MoviesController#excluded_content_ids.
// Passes are always excluded regardless of context.
// Partner context: also excludes user's likes + relationship favorites.
// Group context: also excludes user's group_likes in that group.
async function getExcludedIds(
  userId: string,
  types: Array<'movie' | 'tv'>,
  context: string,
): Promise<Record<string, Set<number>>> {
  const supabase = getAdminClient();
  const result: Record<string, Set<number>> = {};

  for (const tmdbType of types) {
    const { data: passes } = await supabase
      .from('passes')
      .select('api_movie_id')
      .eq('user_id', userId)
      .eq('content_type', tmdbType);

    const excluded = new Set<number>((passes || []).map((p: any) => p.api_movie_id));

    if (context === 'partner') {
      const { data: likes } = await supabase
        .from('likes')
        .select('api_movie_id')
        .eq('user_id', userId)
        .eq('content_type', tmdbType);
      (likes || []).forEach((l: any) => excluded.add(l.api_movie_id));

      const { data: rel } = await supabase
        .from('relationships')
        .select('id')
        .or(`sender_id.eq.${userId},recipient_id.eq.${userId}`)
        .maybeSingle();

      if (rel) {
        const { data: favs } = await supabase
          .from('favorites')
          .select('api_movie_id')
          .eq('relationship_id', rel.id)
          .eq('content_type', tmdbType);
        (favs || []).forEach((f: any) => excluded.add(f.api_movie_id));
      }
    } else {
      const groupId = parseInt(context, 10);
      const { data: groupLikes } = await supabase
        .from('group_likes')
        .select('api_movie_id')
        .eq('user_id', userId)
        .eq('group_id', groupId)
        .eq('content_type', tmdbType);
      (groupLikes || []).forEach((gl: any) => excluded.add(gl.api_movie_id));
    }

    result[tmdbType] = excluded;
  }

  return result;
}

// Replicates MoviesController#fetch_tmdb_page.
async function fetchTmdbPage(
  type: 'movie' | 'tv',
  page: number,
  query: string,
  genreId: string | null,
  watchProviderId: string | null,
  region: string,
): Promise<any[]> {
  let url: string;
  if (query) {
    url = `${TMDB_BASE}/search/${type}?api_key=${tmdbKey()}&language=en-US&include_adult=false&page=${page}&query=${encodeURIComponent(query)}`;
  } else {
    url = `${TMDB_BASE}/discover/${type}?api_key=${tmdbKey()}&language=en-US&sort_by=popularity.desc&include_adult=false&page=${page}`;
    if (genreId) url += `&with_genres=${genreId}`;
    if (watchProviderId) url += `&with_watch_providers=${watchProviderId}&watch_region=${region}`;
  }
  const res = await fetch(url);
  const data = await res.json();
  return data.results || [];
}

// Replicates MoviesController#normalize_browse_item.
function normalizeBrowseItem(item: any, type: 'movie' | 'tv') {
  return {
    id:           item.id,
    title:        type === 'tv' ? item.name : item.title,
    poster_path:  item.poster_path,
    overview:     item.overview,
    release_date: type === 'tv' ? item.first_air_date : item.release_date,
    genre_ids:    item.genre_ids || [],
    popularity:   item.popularity,
    content_type: type,
  };
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
