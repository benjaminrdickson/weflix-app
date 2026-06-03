import { corsHeaders } from '../_shared/cors.ts';
import { getUser, getAdminClient } from '../_shared/auth.ts';
import { fetchProcessedDetail } from '../_shared/tmdb.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  const user = await getUser(req);
  if (!user) return json({ error: 'Unauthorized' }, 401);

  const url = new URL(req.url);
  const idMatch = url.pathname.match(/\/favorites\/(\d+)/);
  const favoriteId = idMatch ? parseInt(idMatch[1], 10) : null;

  try {
    if (req.method === 'DELETE' && favoriteId) {
      return await handleDestroy(user.id, favoriteId);
    }
    if (req.method === 'GET') {
      return await handleIndex(user.id, url.searchParams);
    }
    return json({ error: 'Method not allowed' }, 405);
  } catch (err) {
    console.error(err);
    return json({ error: 'Internal error' }, 500);
  }
});

// Replicates FavoritesController#index exactly.
// Returns [] if user has no relationship.
// Enriches each favorite with TMDB data in parallel, merging favorite_id.
async function handleIndex(userId: string, params: URLSearchParams): Promise<Response> {
  const region = params.get('region') || 'US';
  const supabase = getAdminClient();

  const { data: rel } = await supabase
    .from('relationships')
    .select('id')
    .or(`sender_id.eq.${userId},recipient_id.eq.${userId}`)
    .maybeSingle();

  if (!rel) return json([]);

  const { data: favorites } = await supabase
    .from('favorites')
    .select('id, api_movie_id, content_type')
    .eq('relationship_id', rel.id);

  if (!favorites || favorites.length === 0) return json([]);

  // Enrich all favorites in parallel — replicates favorites.map { |f| build_favorite_json(f, region) }
  const results = await Promise.all(
    favorites.map(async (fav: any) => {
      const tmdbType: 'movie' | 'tv' = fav.content_type === 'tv' ? 'tv' : 'movie';
      const detail = await fetchProcessedDetail(fav.api_movie_id, tmdbType, region);
      return { ...detail, favorite_id: fav.id };
    }),
  );

  return json(results);
}

// Replicates FavoritesController#destroy exactly.
// Verifies the favorite belongs to the current user's relationship before deleting.
async function handleDestroy(userId: string, favoriteId: number): Promise<Response> {
  const supabase = getAdminClient();

  const { data: rel } = await supabase
    .from('relationships')
    .select('id')
    .or(`sender_id.eq.${userId},recipient_id.eq.${userId}`)
    .maybeSingle();

  if (!rel) return json({ error: 'Unauthorized' }, 401);

  const { data: favorite } = await supabase
    .from('favorites')
    .select('id, relationship_id')
    .eq('id', favoriteId)
    .maybeSingle();

  if (!favorite || favorite.relationship_id !== rel.id) {
    return json({ error: 'Unauthorized' }, 401);
  }

  await supabase.from('favorites').delete().eq('id', favoriteId);

  return json({ message: 'Favorite successfully destroyed' });
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
