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
  const idMatch = url.pathname.match(/\/relationships\/(\d+)/);
  const relId = idMatch ? parseInt(idMatch[1], 10) : null;

  try {
    if (req.method === 'POST')   return await handleCreate(user.id, req);
    if (req.method === 'PATCH'  && relId) return await handleUpdate(user.id, relId);
    if (req.method === 'DELETE' && relId) return await handleDestroy(user.id, relId);
    return json({ error: 'Method not allowed' }, 405);
  } catch (err) {
    console.error(err);
    return json({ error: 'Internal error' }, 500);
  }
});

// Replicates RelationshipsController#create.
// Creates with sender_id = caller, confirmation = false. Notifies recipient.
async function handleCreate(userId: string, req: Request): Promise<Response> {
  const body = await req.json();
  const recipientId: string = body.recipient_id;

  if (!recipientId) return json({ error: 'recipient_id required' }, 400);

  // Validate recipientId is a UUID before using it in filter construction.
  const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!UUID_RE.test(recipientId)) return json({ error: 'Invalid recipient_id' }, 400);

  const supabase = getAdminClient();

  // Pre-flight: block if either party is already in a relationship.
  // The DB trigger is the hard guarantee; this produces a friendly 422 for the normal case.
  const { data: conflict } = await supabase
    .from('relationships')
    .select('id')
    .or(
      `sender_id.eq.${userId},recipient_id.eq.${userId},` +
      `sender_id.eq.${recipientId},recipient_id.eq.${recipientId}`
    )
    .limit(1)
    .maybeSingle();

  if (conflict) {
    return json({ error: 'One of you is already in a relationship' }, 422);
  }

  const { data: relationship, error } = await supabase
    .from('relationships')
    .insert({ sender_id: userId, recipient_id: recipientId, confirmation: false })
    .select()
    .single();

  if (error || !relationship) {
    return json({ error: 'Could not create relationship' }, 422);
  }

  // Notify recipient
  const { data: sender } = await supabase
    .from('users')
    .select('name')
    .eq('id', userId)
    .maybeSingle();

  await deliver({
    userIds: [recipientId],
    type:    'partner_invitation',
    message: `${sender?.name ?? 'Someone'} sent you a partner invitation`,
  });

  return json(relationship);
}

// Replicates RelationshipsController#update.
// Only the recipient can confirm. Body is ignored — sets confirmation = true unconditionally.
async function handleUpdate(userId: string, relId: number): Promise<Response> {
  const supabase = getAdminClient();

  const { data: relationship } = await supabase
    .from('relationships')
    .select('id, sender_id, recipient_id')
    .eq('id', relId)
    .maybeSingle();

  if (!relationship) return json({ error: 'Not found' }, 404);
  if (relationship.recipient_id !== userId) return json({}, 401);

  const { data: updated, error } = await supabase
    .from('relationships')
    .update({ confirmation: true })
    .eq('id', relId)
    .select()
    .single();

  if (error || !updated) return json({ error: 'Could not update relationship' }, 422);

  // Notify sender
  const { data: recipient } = await supabase
    .from('users')
    .select('name')
    .eq('id', userId)
    .maybeSingle();

  await deliver({
    userIds: [relationship.sender_id],
    type:    'partner_invitation_approved',
    message: `${recipient?.name ?? 'Someone'} accepted your partner invitation`,
  });

  return json(updated);
}

// Replicates RelationshipsController#destroy.
// Either participant can delete. Cascade in schema handles favorites deletion.
async function handleDestroy(userId: string, relId: number): Promise<Response> {
  const supabase = getAdminClient();

  const { data: relationship } = await supabase
    .from('relationships')
    .select('id, sender_id, recipient_id')
    .eq('id', relId)
    .maybeSingle();

  if (!relationship) return json({ error: 'Not found' }, 404);

  if (relationship.sender_id !== userId && relationship.recipient_id !== userId) {
    return json({ error: 'Unauthorized' }, 401);
  }

  await supabase.from('relationships').delete().eq('id', relId);

  return json({ message: 'Relationship destroyed' });
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
