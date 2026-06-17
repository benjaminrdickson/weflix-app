import { corsHeaders } from '../_shared/cors.ts';
import { getUser, getAdminClient } from '../_shared/auth.ts';
import { fetchProcessedDetail } from '../_shared/tmdb.ts';
import { deliver } from '../_shared/notifications.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  const user = await getUser(req);
  if (!user) return json({ error: 'Unauthorized' }, 401);

  const url  = new URL(req.url);
  const path = url.pathname;

  // Match /groups/{id}/leave before /groups/{id} to avoid false positive
  const leaveMatch = path.match(/\/groups\/(\d+)\/leave/);
  const idMatch    = path.match(/\/groups\/(\d+)(?:\/|$)/);
  const groupId    = leaveMatch
    ? parseInt(leaveMatch[1], 10)
    : idMatch ? parseInt(idMatch[1], 10) : null;

  try {
    if (req.method === 'GET'    && !groupId)  return await handleIndex(user.id);
    if (req.method === 'POST'   && !groupId)  return await handleCreate(user.id, req);
    if (req.method === 'GET'    &&  groupId)  return await handleShow(user.id, groupId, url.searchParams);
    if (req.method === 'PATCH'  &&  groupId)  return await handleUpdate(user.id, groupId, req);
    if (req.method === 'DELETE' &&  groupId && leaveMatch) return await handleLeave(user.id, groupId);
    if (req.method === 'DELETE' &&  groupId)  return await handleDestroy(user.id, groupId);
    return json({ error: 'Method not allowed' }, 405);
  } catch (err) {
    console.error(err);
    return json({ error: 'Internal error' }, 500);
  }
});

// Replicates GroupsController#index.
async function handleIndex(userId: string): Promise<Response> {
  const supabase = getAdminClient();

  const { data: memberships } = await supabase
    .from('group_memberships')
    .select('group_id')
    .eq('user_id', userId);

  if (!memberships || memberships.length === 0) return json([]);

  const groupIds = memberships.map((m: any) => m.group_id);

  const { data: groups } = await supabase
    .from('groups')
    .select('id, name, creator_id')
    .in('id', groupIds);

  if (!groups || groups.length === 0) return json([]);

  const summaries = await Promise.all(groups.map((g: any) => groupSummaryJson(supabase, g, userId)));
  return json(summaries);
}

// Replicates GroupsController#create.
async function handleCreate(userId: string, req: Request): Promise<Response> {
  const body = await req.json();
  const name: string = body.name?.trim();
  if (!name) return json({ errors: ['Name can\'t be blank'] }, 422);

  const supabase = getAdminClient();

  const { data: group, error } = await supabase
    .from('groups')
    .insert({ name, creator_id: userId })
    .select()
    .single();

  if (error || !group) return json({ errors: ['Could not create group'] }, 422);

  await supabase.from('group_memberships').insert({ group_id: group.id, user_id: userId });

  const summary = await groupSummaryJson(supabase, group, userId);
  return json(summary, 201);
}

// Replicates GroupsController#show.
// Returns full detail: members, TMDB-enriched watchlist, pending invitations (creator only).
async function handleShow(userId: string, groupId: number, params: URLSearchParams): Promise<Response> {
  const region = params.get('region') || 'US';
  const supabase = getAdminClient();

  const { data: membership } = await supabase
    .from('group_memberships')
    .select('id')
    .eq('group_id', groupId)
    .eq('user_id', userId)
    .maybeSingle();

  if (!membership) return json({ error: 'Not found' }, 404);

  const { data: group } = await supabase
    .from('groups')
    .select('id, name, creator_id')
    .eq('id', groupId)
    .maybeSingle();

  if (!group) return json({ error: 'Not found' }, 404);

  // Fetch members, watchlist items, pending invitations, and pending ownership invite in parallel
  const [membersResult, watchlistResult, invitationsResult, ownershipInviteResult] = await Promise.all([
    supabase
      .from('group_memberships')
      .select('users!group_memberships_user_id_fkey(id, name, username, image_url)')
      .eq('group_id', groupId),
    supabase
      .from('group_watchlist_items')
      .select('id, api_movie_id, content_type')
      .eq('group_id', groupId),
    group.creator_id === userId
      ? supabase
          .from('group_invitations')
          .select('id, status, users!group_invitations_invitee_id_fkey(id, name, username, image_url)')
          .eq('group_id', groupId)
          .in('status', ['pending', 'accepted'])
      : Promise.resolve({ data: [] }),
    group.creator_id === userId
      ? supabase
          .from('group_ownership_invites')
          .select('id, users!group_ownership_invites_invitee_id_fkey(id, name, username, image_url)')
          .eq('group_id', groupId)
          .eq('status', 'pending')
          .maybeSingle()
      : Promise.resolve({ data: null }),
  ]);

  const members = (membersResult.data || []).map((m: any) => userJson(m.users));
  const ownershipInvite = ownershipInviteResult.data;

  // Enrich watchlist items with TMDB data in parallel
  const watchlist = await Promise.all(
    (watchlistResult.data || []).map(async (item: any) => {
      const tmdbType: 'movie' | 'tv' = item.content_type === 'tv' ? 'tv' : 'movie';
      const detail = await fetchProcessedDetail(item.api_movie_id, tmdbType, region);
      return { ...detail, watchlist_item_id: item.id };
    }),
  );

  const pendingInvitations = (invitationsResult.data || []).map((inv: any) => ({
    invitation_id: inv.id,
    invitee:       userJson(inv.users),
    status:        inv.status,
  }));

  return json({
    id:                  group.id,
    name:                group.name,
    creator_id:          group.creator_id,
    is_creator:          group.creator_id === userId,
    members,
    pending_invitations: pendingInvitations,
    watchlist,
    pending_ownership_invite: ownershipInvite ? {
      invite_id: ownershipInvite.id,
      invitee:   userJson((ownershipInvite as any).users),
    } : null,
  });
}

// Replicates GroupsController#update — rename, creator only.
async function handleUpdate(userId: string, groupId: number, req: Request): Promise<Response> {
  const supabase = getAdminClient();
  const body = await req.json();
  const name: string = body.name?.trim();
  if (!name) return json({ errors: ['Name can\'t be blank'] }, 422);

  const { data: group } = await supabase
    .from('groups')
    .select('id, name, creator_id')
    .eq('id', groupId)
    .maybeSingle();

  if (!group) return json({ error: 'Not found' }, 404);
  if (group.creator_id !== userId) return json({ error: 'Unauthorized' }, 401);

  const { data: updated } = await supabase
    .from('groups')
    .update({ name })
    .eq('id', groupId)
    .select()
    .single();

  const summary = await groupSummaryJson(supabase, updated, userId);
  return json(summary);
}

// Replicates GroupsController#destroy — creator only. Cascade handles all related rows.
async function handleDestroy(userId: string, groupId: number): Promise<Response> {
  const supabase = getAdminClient();

  const { data: group } = await supabase
    .from('groups')
    .select('creator_id')
    .eq('id', groupId)
    .maybeSingle();

  if (!group) return json({ error: 'Not found' }, 404);
  if (group.creator_id !== userId) return json({ error: 'Unauthorized' }, 401);

  await supabase.from('groups').delete().eq('id', groupId);
  return json({ message: 'Group deleted' });
}

// Replicates GroupsController#leave — non-creator members only.
async function handleLeave(userId: string, groupId: number): Promise<Response> {
  const supabase = getAdminClient();

  const { data: membership } = await supabase
    .from('group_memberships')
    .select('id')
    .eq('group_id', groupId)
    .eq('user_id', userId)
    .maybeSingle();

  if (!membership) return json({ error: 'Not found' }, 404);

  const { data: group } = await supabase
    .from('groups')
    .select('creator_id, name')
    .eq('id', groupId)
    .maybeSingle();

  if (group?.creator_id === userId) {
    return json({ error: 'Creator cannot leave — delete the group instead' }, 422);
  }

  // If this user has a pending ownership invite for this group, cancel it and notify the creator.
  const { data: ownershipInvite } = await supabase
    .from('group_ownership_invites')
    .select('id, inviter_id')
    .eq('group_id', groupId)
    .eq('invitee_id', userId)
    .eq('status', 'pending')
    .maybeSingle();

  if (ownershipInvite) {
    await supabase
      .from('group_ownership_invites')
      .update({ status: 'cancelled' })
      .eq('id', ownershipInvite.id);

    const { data: leavingUser } = await supabase
      .from('users')
      .select('name')
      .eq('id', userId)
      .maybeSingle();

    await deliver({
      userIds: [ownershipInvite.inviter_id],
      type:    'group_ownership_invite_cancelled',
      message: `${leavingUser?.name ?? 'Someone'} left "${group?.name ?? 'the group'}" — your ownership transfer invite has been cancelled`,
    });
  }

  await supabase.from('group_memberships').delete().eq('id', membership.id);
  return json({ message: 'Left group' });
}

// Replicates GroupsController#group_summary_json.
async function groupSummaryJson(supabase: any, group: any, userId: string) {
  const [{ count: memberCount }, { count: matchedCount }] = await Promise.all([
    supabase.from('group_memberships').select('*', { count: 'exact', head: true }).eq('group_id', group.id),
    supabase.from('group_watchlist_items').select('*', { count: 'exact', head: true }).eq('group_id', group.id),
  ]);

  return {
    id:            group.id,
    name:          group.name,
    creator_id:    group.creator_id,
    is_creator:    group.creator_id === userId,
    member_count:  memberCount ?? 0,
    matched_count: matchedCount ?? 0,
  };
}

// Replicates GroupsController#user_json. Uses users.image_url directly.
function userJson(user: any) {
  return {
    id:        user?.id,
    name:      user?.name,
    username:  user?.username,
    image_url: user?.image_url ?? null,
  };
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
