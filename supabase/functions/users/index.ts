import { corsHeaders } from '../_shared/cors.ts';
import { getUser, getAdminClient } from '../_shared/auth.ts';
import { deliver } from '../_shared/notifications.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  const user = await getUser(req);
  if (!user) return json({ error: 'Unauthorized' }, 401);

  const url      = new URL(req.url);
  const segments = url.pathname.split('/').filter(Boolean);
  // Last segment after "users" is either "search", a username (GET), or UUID (PATCH/DELETE)
  const param = segments[segments.indexOf('users') + 1] ?? null;

  try {
    // Search route: GET users/search?q=... — partial username/name match
    if (param === 'search' && req.method === 'GET') return await handleSearch(user.id, url);
    if (param === 'search') return json({ error: 'Method not allowed' }, 405);

    if (!param) return json({ error: 'Not found' }, 404);

    if (req.method === 'GET')    return await handleShow(param);
    if (req.method === 'PATCH')  return await handleUpdate(user.id, param, req);
    if (req.method === 'DELETE') return await handleDestroy(user.id, param);
    return json({ error: 'Method not allowed' }, 405);
  } catch (err) {
    console.error(err);
    return json({ error: 'Internal error' }, 500);
  }
});

// Partial user search: contains match on username and name.
// Returns id/username/name/image_url only — no email (multi-user PII exposure risk).
async function handleSearch(callerId: string, url: URL): Promise<Response> {
  const q = (url.searchParams.get('q') ?? '').trim();

  // Require at least 2 characters to avoid unbounded full-table scans.
  if (q.length < 2) return json([]);

  // Escape SQL LIKE metacharacters so user-supplied %, _, \ are treated as
  // literals, not wildcards. Confirmed correct: PostgreSQL honors \ as the
  // default ILIKE escape character in parameterized queries (tested against
  // real DB — escaped % returned 1 match, unescaped % returned all rows).
  const escaped = q.replace(/\\/g, '\\\\').replace(/%/g, '\\%').replace(/_/g, '\\_');
  const pattern = `%${escaped}%`;

  const supabase = getAdminClient();

  // Two separate .ilike() calls instead of .or() — avoids PostgREST
  // filter-string mis-parsing when the search term contains commas.
  // Per-query limit is 50 so the ranking pool is large enough that
  // the final top-20 slice isn't distorted by a tight per-query cap.
  const [{ data: byUsername }, { data: byName }] = await Promise.all([
    supabase
      .from('users')
      .select('id, username, name, image_url')
      .ilike('username', pattern)
      .neq('id', callerId)
      // TODO: exclude users who have blocked or been blocked by the caller
      .limit(50),
    supabase
      .from('users')
      .select('id, username, name, image_url')
      .ilike('name', pattern)
      .neq('id', callerId)
      // TODO: exclude users who have blocked or been blocked by the caller
      .limit(50),
  ]);

  // Track username-query matches for relevance ranking.
  const usernameMatchIds = new Set((byUsername ?? []).map(u => u.id));

  // Merge, deduplicate (a user matching both fields appears once).
  const seen = new Set<string>();
  const candidates = [...(byUsername ?? []), ...(byName ?? [])].filter(u => {
    if (seen.has(u.id)) return false;
    seen.add(u.id);
    return true;
  });

  // Relevance ranking (lower = better):
  //   0 — exact username match
  //   1 — exact name match
  //   2 — username starts with term
  //   3 — name starts with term
  //   4 — contains match on username
  //   5 — contains match on name only
  // Tiebreaker: alphabetical by username.
  const lTerm = q.toLowerCase();
  function rankScore(u: { id: string; username: string; name: string | null }): number {
    const uname = u.username.toLowerCase();
    const uname_field = (u.name ?? '').toLowerCase();
    if (uname === lTerm)               return 0;
    if (uname_field === lTerm)         return 1;
    if (uname.startsWith(lTerm))       return 2;
    if (uname_field.startsWith(lTerm)) return 3;
    if (usernameMatchIds.has(u.id))    return 4;
    return 5;
  }

  // Rank first, then cap at 20 — so the top 20 are the most relevant, not arbitrary.
  const results = candidates
    .sort((a, b) => {
      const diff = rankScore(a) - rankScore(b);
      if (diff !== 0) return diff;
      return a.username.toLowerCase().localeCompare(b.username.toLowerCase());
    })
    .slice(0, 20);

  return json(results);
}

// Replicates UsersController#show.
// Returns full profile: relationship with is_sender + partner, is_group_creator flag.
// Uses users.image_url directly — no Active Storage.
async function handleShow(username: string): Promise<Response> {
  const supabase = getAdminClient();

  const { data: user } = await supabase
    .from('users')
    .select('id, name, username, image_url')
    .ilike('username', username)
    .maybeSingle();

  if (!user) return json({ error: 'User not found' }, 404);

  // Find relationship
  const { data: rel } = await supabase
    .from('relationships')
    .select('id, sender_id, recipient_id, confirmation')
    .or(`sender_id.eq.${user.id},recipient_id.eq.${user.id}`)
    .maybeSingle();

  // Find partner if relationship exists
  let partner = null;
  if (rel) {
    const partnerId = rel.sender_id === user.id ? rel.recipient_id : rel.sender_id;
    const { data: partnerData } = await supabase
      .from('users')
      .select('id, name, username, image_url')
      .eq('id', partnerId)
      .maybeSingle();
    partner = partnerData;
  }

  // Check if user has created any groups
  const { count: groupCount } = await supabase
    .from('groups')
    .select('*', { count: 'exact', head: true })
    .eq('creator_id', user.id);

  return json({
    id:               user.id,
    name:             user.name,
    username:         user.username,
    image_url:        user.image_url ?? null,
    is_group_creator: (groupCount ?? 0) > 0,
    relationship: rel ? {
      id:        rel.id,
      confirmed: rel.confirmation,
      is_sender: rel.sender_id === user.id,
      partner:   partner ? {
        id:        partner.id,
        name:      partner.name,
        username:  partner.username,
        image_url: partner.image_url ?? null,
      } : null,
    } : null,
  });
}

// Replicates UsersController#update.
// Only caller can update their own profile. Password excluded — handled by Supabase Auth.
async function handleUpdate(callerId: string, userId: string, req: Request): Promise<Response> {
  if (callerId !== userId) return json({ error: 'Unauthorized' }, 401);

  const supabase = getAdminClient();
  const body = await req.json();

  // Fetch current values to use as fallbacks (replicates: user.name = params[:name] || user.name)
  const { data: current } = await supabase
    .from('users')
    .select('name, email, username, image_url')
    .eq('id', userId)
    .maybeSingle();

  if (!current) return json({ error: 'Not found' }, 404);

  const updates: Record<string, string> = {
    name:      body.name      ?? current.name,
    email:     body.email     ?? current.email,
    username:  body.username  ?? current.username,
    image_url: body.image_url ?? current.image_url,
  };

  const { data: updated, error } = await supabase
    .from('users')
    .update(updates)
    .eq('id', userId)
    .select('id, name, username, email, image_url')
    .single();

  if (error) {
    return json({ errors: [error.message] }, 422);
  }

  return json(updated);
}

// Deletes the caller's account with full cascade.
// Groups where the caller is creator with other members get ownership transferred
// to the earliest-joined member before deletion. Storage avatar is also removed.
async function handleDestroy(callerId: string, userId: string): Promise<Response> {
  if (callerId !== userId) return json({ error: 'Unauthorized' }, 401);

  const supabase = getAdminClient();

  // Step 1: Transfer ownership of groups this user created that have other members.
  // Must happen before deletion because groups.creator_id has ON DELETE CASCADE.
  const { data: createdGroups } = await supabase
    .from('groups')
    .select('id, name')
    .eq('creator_id', userId);

  for (const group of (createdGroups || [])) {
    const { data: otherMembers } = await supabase
      .from('group_memberships')
      .select('user_id, created_at')
      .eq('group_id', group.id)
      .neq('user_id', userId)
      .order('created_at', { ascending: true });

    if (!otherMembers || otherMembers.length === 0) continue; // sole member — cascade deletes it

    const newOwner = otherMembers[0];
    const { error: transferError } = await supabase
      .from('groups')
      .update({ creator_id: newOwner.user_id })
      .eq('id', group.id);

    if (transferError) return json({ error: 'Could not transfer group ownership' }, 422);

    await deliver({
      userIds: [newOwner.user_id],
      type:    'group_ownership_transfer',
      message: `You are now the owner of "${group.name}" — the previous owner deleted their account`,
    });
  }

  // Step 2: Delete avatar files from storage.
  const { data: storageFiles } = await supabase.storage.from('avatars').list(userId);
  if (storageFiles && storageFiles.length > 0) {
    const paths = storageFiles.map((f: any) => `${userId}/${f.name}`);
    await supabase.storage.from('avatars').remove(paths);
  }

  // Step 3: Delete auth user — cascades to public.users and all related rows.
  const { error } = await supabase.auth.admin.deleteUser(userId);
  if (error) return json({ error: 'Could not delete account' }, 422);

  return json({ message: 'Account deleted' });
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
