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
    const token: string    = String(body.token ?? '').trim();
    const platform: string = String(body.platform ?? '').trim();

    if (!token) return json({ error: 'Invalid token' }, 422);

    const supabase = getAdminClient();

    // Replicates PushTokensController#upsert: find_or_initialize_by(user) + assign + save.
    // Unique per user — upsert updates token/platform if user already has one registered.
    const { error } = await supabase
      .from('push_tokens')
      .upsert(
        { user_id: user.id, token, platform },
        { onConflict: 'user_id' },
      );

    if (error) return json({ error: 'Could not register token' }, 422);

    return json({ message: 'Token registered' });
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
