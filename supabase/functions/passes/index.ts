import { corsHeaders } from '../_shared/cors.ts';
import { getUser, getAdminClient } from '../_shared/auth.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  const user = await getUser(req);
  if (!user) return json({ error: 'Unauthorized' }, 401);
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const body = await req.json();
    const apiMovieId = parseInt(body.api_movie_id, 10);
    const contentType: string = body.content_type || 'movie';

    const supabase = getAdminClient();

    // Replicates PassesController: find_or_initialize_by + save.
    // Unique constraint on (user_id, api_movie_id, content_type) handles duplicates.
    const { data: pass, error } = await supabase
      .from('passes')
      .upsert(
        { user_id: user.id, api_movie_id: apiMovieId, content_type: contentType },
        { onConflict: 'user_id,api_movie_id,content_type' },
      )
      .select()
      .single();

    if (error || !pass) {
      return json({ error: 'Could not save pass' }, 400);
    }

    return json(pass);
  } catch (err) {
    console.error(err);
    return json({ error: 'Internal error' }, 500);
  }
});

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
