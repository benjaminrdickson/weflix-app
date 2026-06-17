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
  const idMatch = url.pathname.match(/\/group-ownership-invites\/(\d+)/);
  const groupId = idMatch ? parseInt(idMatch[1], 10) : null;

  if (!groupId) return json({ error: 'Group ID required' }, 400);

  try {
    if (req.method === 'POST')   return await handleCreate(user.id, groupId, req);
    if (req.method === 'PATCH')  return await handleRespond(user.id, groupId, req);
    if (req.method === 'DELETE') return await handleCancel(user.id, groupId);
    return json({ error: 'Method not allowed' }, 405);
  } catch (err) {
    console.error(err);
    return json({ error: 'Internal error' }, 500);
  }
});

// Creator sends an ownership invite to a current group member.
async function handleCreate(userId: string, groupId: number, req: Request): Promise<Response> {
  const supabase = getAdminClient();
  const body = await req.json();
  const inviteeId: string = body.invitee_id;

  if (!inviteeId) return json({ error: 'invitee_id required' }, 400);
  if (inviteeId === userId) return json({ error: 'Cannot transfer ownership to yourself' }, 422);

  // Verify caller is current creator
  const { data: group } = await supabase
    .from('groups')
    .select('id, name, creator_id')
    .eq('id', groupId)
    .maybeSingle();

  if (!group) return json({ error: 'Group not found' }, 404);
  if (group.creator_id !== userId) return json({ error: 'Only the group creator can transfer ownership' }, 401);

  // Verify invitee is a current member
  const { data: membership } = await supabase
    .from('group_memberships')
    .select('id')
    .eq('group_id', groupId)
    .eq('user_id', inviteeId)
    .maybeSingle();

  if (!membership) return json({ error: 'User is not a group member' }, 422);

  // Cancel any existing pending invite for this group (idempotent re-send)
  await supabase
    .from('group_ownership_invites')
    .update({ status: 'cancelled' })
    .eq('group_id', groupId)
    .eq('status', 'pending');

  // Create new invite
  const { data: invite, error: insertError } = await supabase
    .from('group_ownership_invites')
    .insert({ group_id: groupId, inviter_id: userId, invitee_id: inviteeId })
    .select()
    .single();

  if (insertError || !invite) return json({ error: 'Could not send invite' }, 422);

  const { data: creator } = await supabase
    .from('users')
    .select('name')
    .eq('id', userId)
    .maybeSingle();

  await deliver({
    userIds: [inviteeId],
    type:    'group_ownership_invite',
    message: `${creator?.name ?? 'Someone'} has invited you to become the owner of "${group.name}". Accept or decline?`,
    context: JSON.stringify({ invite_id: invite.id, group_id: groupId }),
  });

  return json({ invite_id: invite.id }, 201);
}

// Invitee accepts or declines the invite.
async function handleRespond(userId: string, groupId: number, req: Request): Promise<Response> {
  const supabase = getAdminClient();
  const body = await req.json();
  const inviteId: number = parseInt(body.invite_id, 10);
  const accepted: boolean = String(body.accepted) === 'true';

  if (!inviteId) return json({ error: 'invite_id required' }, 400);

  const { data: invite } = await supabase
    .from('group_ownership_invites')
    .select('id, group_id, inviter_id, invitee_id, status')
    .eq('id', inviteId)
    .eq('group_id', groupId)
    .maybeSingle();

  if (!invite) return json({ error: 'Invite not found' }, 404);
  if (invite.invitee_id !== userId) return json({ error: 'Unauthorized' }, 401);
  if (invite.status !== 'pending') return json({ error: 'This invite is no longer pending' }, 422);

  const { data: group } = await supabase
    .from('groups')
    .select('id, name')
    .eq('id', groupId)
    .maybeSingle();

  if (!group) return json({ error: 'Group not found' }, 404);

  if (accepted) {
    const { error: transferError } = await supabase
      .from('groups')
      .update({ creator_id: userId })
      .eq('id', groupId);

    if (transferError) return json({ error: 'Could not transfer ownership' }, 422);

    await supabase
      .from('group_ownership_invites')
      .update({ status: 'accepted' })
      .eq('id', inviteId);

    const { data: newOwner } = await supabase
      .from('users')
      .select('name')
      .eq('id', userId)
      .maybeSingle();

    await Promise.all([
      deliver({
        userIds: [userId],
        type:    'group_ownership_transfer',
        message: `You are now the owner of "${group.name}"`,
      }),
      deliver({
        userIds: [invite.inviter_id],
        type:    'group_ownership_invite_accepted',
        message: `${newOwner?.name ?? 'Someone'} accepted your ownership invite — they are now the owner of "${group.name}"`,
      }),
    ]);

    return json({ status: 'accepted' });
  } else {
    await supabase
      .from('group_ownership_invites')
      .update({ status: 'declined' })
      .eq('id', inviteId);

    const { data: invitee } = await supabase
      .from('users')
      .select('name')
      .eq('id', userId)
      .maybeSingle();

    await deliver({
      userIds: [invite.inviter_id],
      type:    'group_ownership_invite_declined',
      message: `${invitee?.name ?? 'Someone'} declined your ownership invite for "${group.name}"`,
    });

    return json({ status: 'declined' });
  }
}

// Creator cancels a pending invite.
async function handleCancel(userId: string, groupId: number): Promise<Response> {
  const supabase = getAdminClient();

  const { data: invite } = await supabase
    .from('group_ownership_invites')
    .select('id')
    .eq('group_id', groupId)
    .eq('inviter_id', userId)
    .eq('status', 'pending')
    .maybeSingle();

  if (!invite) return json({ error: 'No pending invite found' }, 404);

  await supabase
    .from('group_ownership_invites')
    .update({ status: 'cancelled' })
    .eq('id', invite.id);

  return json({ message: 'Invite cancelled' });
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
