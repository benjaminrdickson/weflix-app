import { corsHeaders } from '../_shared/cors.ts';
import { getUser } from '../_shared/auth.ts';

const TMDB_BASE = 'https://api.themoviedb.org/3';
const tmdbKey = () => Deno.env.get('TMDB_API_KEY') ?? '';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  const user = await getUser(req);
  if (!user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const url = new URL(req.url);
    const contentType = url.searchParams.get('content_type') || 'movie';

    // Replicates GenresController#index exactly.
    // "tv" → only tv genres; "both" → movie + tv; anything else → movie only
    const types: string[] =
      contentType === 'tv' ? ['tv'] :
      contentType === 'both' ? ['movie', 'tv'] :
      ['movie'];

    const allGenres = (
      await Promise.all(
        types.map(async (type) => {
          const res = await fetch(
            `${TMDB_BASE}/genre/${type}/list?api_key=${tmdbKey()}&language=en-US`
          );
          const data = await res.json();
          return data.genres || [];
        })
      )
    ).flat();

    // Deduplicate by id, sort alphabetically by name
    const seen = new Set<number>();
    const unique = allGenres
      .filter((g: any) => {
        if (seen.has(g.id)) return false;
        seen.add(g.id);
        return true;
      })
      .sort((a: any, b: any) => a.name.localeCompare(b.name));

    return new Response(JSON.stringify(unique), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ error: 'Internal error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
