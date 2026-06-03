import { corsHeaders } from '../_shared/cors.ts';
import { getUser, getAdminClient } from '../_shared/auth.ts';
import { deliver } from '../_shared/notifications.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  const user = await getUser(req);
  if (!user) return json({ error: 'Unauthorized' }, 401);

  const url = new URL(req.url);
  const idMatch = url.pathname.match(/\/friendships\/(\d+)/);
  const friendshipId = idMatch ? parseInt(idMatch[1], 10) : null;

  try {
    if (req.method === 'GET')    return await handleIndex(user.id);
    if (req.method === 'POST')   return await handleCreate(user.id, req);
    if (req.method === 'PATCH'  && friendshipId) return await handleUpdate(user.id, friendshipId);
    if (req.method === 'DELETE' && friendshipId) return await handleDestroy(user.id, friendshipId);
    return json({ error: 'Method not allowed' }, 405);
  } catch (err) {
    console.error(err);
    return json({ error: 'Internal error' }, 500);
  }
});

// Replicates FriendshipsController#index.
// friends: confirmed in both directions. pending_requests: received, unconfirmed only.
async function handleIndex(userId: string): Promise<Response> {
  const supabase = getAdminClient();

  // Confirmed friendships where user is sender
  const { data: sentConfirmed } = await supabase
    .from('friendships')
    .select('id, recipient_id, users!friendships_recipient_id_fkey(id, name, username, image_url)')
    .eq('sender_id', userId)
    .eq('confirmed', true);

  // Confirmed friendships where user is recipient
  const { data: receivedConfirmed } = await supabase
    .from('friendships')
    .select('id, sender_id, users!friendships_sender_id_fkey(id, name, username, image_url)')
    .eq('recipient_id', userId)
    .eq('confirmed', true);

  // Pending: received but not yet confirmed (user is recipient)
  const { data: pending } = await supabase
    .from('friendships')
    .select('id, sender_id, users!friendships_sender_id_fkey(id, name, username, image_url)')
    .eq('recipient_id', userId)
    .eq('confirmed', false);

  const friends = [
    ...(sentConfirmed || []).map((f: any) => ({
      ...userJson(f.users),
      friendship_id: f.id,
    })),
    ...(receivedConfirmed || []).map((f: any) => ({
      ...userJson(f.users),
      friendship_id: f.id,
    })),
  ];

  const pendingRequests = (pending || []).map((f: any) => ({
    ...userJson(f.users),
    friendship_id: f.id,
  }));

  return json({ friends, pending_requests: pendingRequests });
}

// Replicates FriendshipsController#create.
// Finds recipient by username. Checks not-self and no existing friendship either direction.
async function handleCreate(userId: string, req: Request): Promise<Response> {
  const body = await req.json();
  const username: string = body.username;
  if (!username) return json({ error: 'username required' }, 400);

  const supabase = getAdminClient();

  const { data: recipient } = await supabase
    .from('users')
    .select('id, name, username, image_url')
    .eq('username', username)
    .maybeSingle();

  if (!recipient) return json({ error: 'User not found' }, 404);
  if (recipient.id === userId) {
    return json({ error: 'Cannot send a friend request to yourself' }, 422);
  }

  // Check both directions for an existing friendship
  const { data: existingA } = await supabase
    .from('friendships')
    .select('id')
    .eq('sender_id', userId)
    .eq('recipient_id', recipient.id)
    .maybeSingle();

  const { data: existingB } = await supabase
    .from('friendships')
    .select('id')
    .eq('sender_id', recipient.id)
    .eq('recipient_id', userId)
    .maybeSingle();

  if (existingA || existingB) {
    return json({ error: 'Friendship already exists' }, 422);
  }

  const { data: friendship, error } = await supabase
    .from('friendships')
    .insert({ sender_id: userId, recipient_id: recipient.id, confirmed: false })
    .select()
    .single();

  if (error || !friendship) {
    return json({ error: 'Could not create friendship' }, 422);
  }

  const { data: sender } = await supabase
    .from('users')
    .select('name')
    .eq('id', userId)
    .maybeSingle();

  await deliver({
    userIds: [recipient.id],
    type:    'friend_request',
    message: `${sender?.name ?? 'Someone'} sent you a friend request`,
  });

  return json({ friendship_id: friendship.id, recipient: userJson(recipient) }, 201);
}

// Replicates FriendshipsController#update.
// Only the recipient can confirm. Notifies sender.
async function handleUpdate(userId: string, friendshipId: number): Promise<Response> {
  const supabase = getAdminClient();

  const { data: friendship } = await supabase
    .from('friendships')
    .select('id, sender_id, recipient_id')
    .eq('id', friendshipId)
    .maybeSingle();

  if (!friendship) return json({ error: 'Not found' }, 404);
  if (friendship.recipient_id !== userId) return json({ error: 'Unauthorized' }, 401);

  const { data: updated, error } = await supabase
    .from('friendships')
    .update({ confirmed: true })
    .eq('id', friendshipId)
    .select()
    .single();

  if (error || !updated) return json({ error: 'Could not update friendship' }, 422);

  const { data: recipient } = await supabase
    .from('users')
    .select('name, id, username, image_url')
    .eq('id', userId)
    .maybeSingle();

  await deliver({
    userIds: [friendship.sender_id],
    type:    'friend_request_accepted',
    message: `${recipient?.name ?? 'Someone'} accepted your friend request`,
  });

  return json({ friendship_id: updated.id, sender: userJson(recipient) });
}

// Replicates FriendshipsController#destroy.
// Either participant can remove.
async function handleDestroy(userId: string, friendshipId: number): Promise<Response> {
  const supabase = getAdminClient();

  const { data: friendship } = await supabase
    .from('friendships')
    .select('id, sender_id, recipient_id')
    .eq('id', friendshipId)
    .maybeSingle();

  if (!friendship) return json({ error: 'Not found' }, 404);

  if (friendship.sender_id !== userId && friendship.recipient_id !== userId) {
    return json({ error: 'Unauthorized' }, 401);
  }

  await supabase.from('friendships').delete().eq('id', friendshipId);

  return json({ message: 'Friendship removed' });
}

// Replicates FriendshipsController#user_json.
// Uses users.image_url directly — no Active Storage in Supabase.
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
