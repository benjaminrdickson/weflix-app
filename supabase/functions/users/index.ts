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
  // Last segment after "users" is either username (GET) or UUID (PATCH/DELETE)
  const param = segments[segments.indexOf('users') + 1] ?? null;

  if (!param) return json({ error: 'Not found' }, 404);

  try {
    if (req.method === 'GET')    return await handleShow(param);
    if (req.method === 'PATCH')  return await handleUpdate(user.id, param, req);
    if (req.method === 'DELETE') return await handleDestroy(user.id, param);
    return json({ error: 'Method not allowed' }, 405);
  } catch (err) {
    console.error(err);
    return json({ error: 'Internal error' }, 500);
  }
});

// Replicates UsersController#show.
// Returns full profile: relationship with is_sender + partner, is_group_creator flag.
// Uses users.image_url directly — no Active Storage.
async function handleShow(username: string): Promise<Response> {
  const supabase = getAdminClient();

  const { data: user } = await supabase
    .from('users')
    .select('id, name, username, email, image_url')
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
    email:            user.email,
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
