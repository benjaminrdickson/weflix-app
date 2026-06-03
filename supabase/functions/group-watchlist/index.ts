import { corsHeaders } from '../_shared/cors.ts';
import { getUser, getAdminClient } from '../_shared/auth.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  const user = await getUser(req);
  if (!user) return json({ error: 'Unauthorized' }, 401);
  if (req.method !== 'DELETE') return json({ error: 'Method not allowed' }, 405);

  // Extract group_id and item_id: /group-watchlist/{groupId}/{itemId}
  const url = new URL(req.url);
  const pathMatch = url.pathname.match(/\/group-watchlist\/(\d+)\/(\d+)/);
  if (!pathMatch) return json({ error: 'Group ID and item ID required' }, 400);

  const groupId  = parseInt(pathMatch[1], 10);
  const itemId   = parseInt(pathMatch[2], 10);

  try {
    const supabase = getAdminClient();

    // Verify user is a member of the group
    const { data: membership } = await supabase
      .from('group_memberships')
      .select('id')
      .eq('group_id', groupId)
      .eq('user_id', user.id)
      .maybeSingle();

    if (!membership) return json({ error: 'Not found' }, 404);

    // Find the watchlist item within this group
    const { data: item } = await supabase
      .from('group_watchlist_items')
      .select('id')
      .eq('id', itemId)
      .eq('group_id', groupId)
      .maybeSingle();

    if (!item) return json({ error: 'Not found' }, 404);

    await supabase.from('group_watchlist_items').delete().eq('id', itemId);

    return json({ message: 'Removed from watchlist' });
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
