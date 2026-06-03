import { corsHeaders } from '../_shared/cors.ts';
import { getUser, getAdminClient } from '../_shared/auth.ts';
import { deliver } from '../_shared/notifications.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  const user = await getUser(req);
  if (!user) return json({ error: 'Unauthorized' }, 401);
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const url = new URL(req.url);
  const groupIdMatch = url.pathname.match(/\/group-likes\/(\d+)/);
  if (!groupIdMatch) return json({ error: 'Group ID required' }, 400);
  const groupId = parseInt(groupIdMatch[1], 10);

  try {
    const body = await req.json();
    const apiMovieId = parseInt(body.api_movie_id, 10);
    const contentType: string = body.content_type || 'movie';

    const supabase = getAdminClient();

    // Verify user is a member of the group
    const { data: membership } = await supabase
      .from('group_memberships')
      .select('id')
      .eq('group_id', groupId)
      .eq('user_id', user.id)
      .maybeSingle();

    if (!membership) return json({ error: 'Not found' }, 404);

    // Check if already liked — replicates find_or_initialize_by + persisted? check
    const { data: existing } = await supabase
      .from('group_likes')
      .select('id')
      .eq('group_id', groupId)
      .eq('user_id', user.id)
      .eq('api_movie_id', apiMovieId)
      .eq('content_type', contentType)
      .maybeSingle();

    if (existing) return json({ message: 'Already liked' });

    // Save the group like
    const { data: groupLike, error } = await supabase
      .from('group_likes')
      .insert({ group_id: groupId, user_id: user.id, api_movie_id: apiMovieId, content_type: contentType })
      .select()
      .single();

    if (error || !groupLike) {
      return json({ error: 'Could not save like' }, 400);
    }

    // Check majority vote threshold after saving
    await checkThreshold(supabase, groupId, apiMovieId, contentType);

    return json({ group_like_id: groupLike.id }, 201);
  } catch (err) {
    console.error(err);
    return json({ error: 'Internal error' }, 500);
  }
});

// Replicates GroupLikesController#check_threshold exactly.
// Strict > 0.5 — 50% does NOT trigger. Only notifies if the watchlist item is NEWLY created.
async function checkThreshold(
  supabase: any,
  groupId: number,
  apiMovieId: number,
  contentType: string,
) {
  const [{ count: memberCount }, { count: likesCount }] = await Promise.all([
    supabase
      .from('group_memberships')
      .select('*', { count: 'exact', head: true })
      .eq('group_id', groupId),
    supabase
      .from('group_likes')
      .select('*', { count: 'exact', head: true })
      .eq('group_id', groupId)
      .eq('api_movie_id', apiMovieId)
      .eq('content_type', contentType),
  ]);

  if (!memberCount || !likesCount) return;
  if (likesCount / memberCount <= 0.5) return;

  // Try to insert watchlist item. ignoreDuplicates means ON CONFLICT DO NOTHING.
  // If data is null, the row already existed — do not re-notify.
  const { data: inserted } = await supabase
    .from('group_watchlist_items')
    .upsert(
      { group_id: groupId, api_movie_id: apiMovieId, content_type: contentType },
      { onConflict: 'group_id,api_movie_id,content_type', ignoreDuplicates: true },
    )
    .select()
    .maybeSingle();

  if (!inserted) return;

  const { data: group } = await supabase
    .from('groups')
    .select('name')
    .eq('id', groupId)
    .maybeSingle();

  const { data: members } = await supabase
    .from('group_memberships')
    .select('user_id')
    .eq('group_id', groupId);

  if (!members || members.length === 0) return;

  await deliver({
    userIds: members.map((m: any) => m.user_id),
    type:    'group_watchlist_match',
    message: `A new title was added to ${group?.name ?? 'your group'}!`,
    context: `group_${groupId}`,
  });
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
