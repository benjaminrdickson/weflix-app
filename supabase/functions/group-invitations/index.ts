import { corsHeaders } from '../_shared/cors.ts';
import { getUser, getAdminClient } from '../_shared/auth.ts';
import { deliver } from '../_shared/notifications.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  const user = await getUser(req);
  if (!user) return json({ error: 'Unauthorized' }, 401);

  const url  = new URL(req.url);
  const path = url.pathname;

  // /group-invitations/{groupId}/{invitationId}
  const updateMatch = path.match(/\/group-invitations\/(\d+)\/(\d+)/);
  // /group-invitations/{groupId}
  const createMatch = path.match(/\/group-invitations\/(\d+)(?:\/|$)/);

  try {
    if (req.method === 'POST'  && createMatch && !updateMatch) {
      return await handleCreate(user.id, parseInt(createMatch[1], 10), req);
    }
    if (req.method === 'PATCH' && updateMatch) {
      return await handleUpdate(
        user.id,
        parseInt(updateMatch[1], 10),
        parseInt(updateMatch[2], 10),
        req,
      );
    }
    return json({ error: 'Method not allowed' }, 405);
  } catch (err) {
    console.error(err);
    return json({ error: 'Internal error' }, 500);
  }
});

// Replicates GroupInvitationsController#create.
// Validates friendship, membership, handles re-invitation of declined/rejected invitations.
async function handleCreate(userId: string, groupId: number, req: Request): Promise<Response> {
  const body = await req.json();
  const inviteeId: string = body.invitee_id;
  if (!inviteeId) return json({ error: 'invitee_id required' }, 400);

  const supabase = getAdminClient();

  // Caller must be a group member
  const { data: membership } = await supabase
    .from('group_memberships')
    .select('id')
    .eq('group_id', groupId)
    .eq('user_id', userId)
    .maybeSingle();

  if (!membership) return json({ error: 'Not found' }, 404);

  // Invitee must exist
  const { data: invitee } = await supabase
    .from('users')
    .select('id, name')
    .eq('id', inviteeId)
    .maybeSingle();

  if (!invitee) return json({ error: 'User not found' }, 404);

  // Must be confirmed friends (check both directions)
  const { data: friendA } = await supabase
    .from('friendships')
    .select('id, confirmed')
    .eq('sender_id', userId)
    .eq('recipient_id', inviteeId)
    .maybeSingle();

  const { data: friendB } = await supabase
    .from('friendships')
    .select('id, confirmed')
    .eq('sender_id', inviteeId)
    .eq('recipient_id', userId)
    .maybeSingle();

  const friendship = friendA || friendB;
  if (!friendship?.confirmed) return json({ error: 'You can only invite friends' }, 403);

  // Invitee must not already be a member
  const { data: existingMembership } = await supabase
    .from('group_memberships')
    .select('id')
    .eq('group_id', groupId)
    .eq('user_id', inviteeId)
    .maybeSingle();

  if (existingMembership) return json({ error: 'User is already a member' }, 422);

  // Check for an existing invitation (unique on group_id + invitee_id)
  const { data: existingInv } = await supabase
    .from('group_invitations')
    .select('id, status')
    .eq('group_id', groupId)
    .eq('invitee_id', inviteeId)
    .maybeSingle();

  // Pending invitation cannot be re-sent
  if (existingInv?.status === 'pending') {
    return json({ error: 'Invitation already sent' }, 422);
  }

  let invitation: any;

  if (existingInv) {
    // Re-invitation: reset declined/rejected invitation to pending with new inviter
    const { data: updated } = await supabase
      .from('group_invitations')
      .update({ status: 'pending', inviter_id: userId })
      .eq('id', existingInv.id)
      .select()
      .single();
    invitation = updated;
  } else {
    // New invitation
    const { data: created } = await supabase
      .from('group_invitations')
      .insert({ group_id: groupId, inviter_id: userId, invitee_id: inviteeId, status: 'pending' })
      .select()
      .single();
    invitation = created;
  }

  if (!invitation) return json({ error: 'Could not create invitation' }, 422);

  // Fetch caller name and group name for notification
  const [{ data: sender }, { data: group }] = await Promise.all([
    supabase.from('users').select('name').eq('id', userId).maybeSingle(),
    supabase.from('groups').select('name').eq('id', groupId).maybeSingle(),
  ]);

  // context is stored as JSON string — NotificationsScreen parses it for inline accept/decline
  await deliver({
    userIds: [inviteeId],
    type:    'group_invitation',
    message: `${sender?.name ?? 'Someone'} invited you to join ${group?.name ?? 'a group'}`,
    context: JSON.stringify({ group_id: groupId, invitation_id: invitation.id }),
  });

  return json({ invitation_id: invitation.id }, 201);
}

// Replicates GroupInvitationsController#update — all 5 status transitions.
async function handleUpdate(
  userId: string,
  groupId: number,
  invitationId: number,
  req: Request,
): Promise<Response> {
  const body = await req.json();
  const supabase = getAdminClient();

  const { data: group } = await supabase
    .from('groups')
    .select('id, name, creator_id')
    .eq('id', groupId)
    .maybeSingle();

  if (!group) return json({ error: 'Not found' }, 404);

  const { data: invitation } = await supabase
    .from('group_invitations')
    .select('id, status, inviter_id, invitee_id')
    .eq('id', invitationId)
    .eq('group_id', groupId)
    .maybeSingle();

  if (!invitation) return json({ error: 'Not found' }, 404);

  if (userId === invitation.invitee_id) {
    return await handleInviteeResponse(supabase, userId, group, invitation, body);
  }

  if (userId === group.creator_id) {
    return await handleCreatorResponse(supabase, group, invitation, body);
  }

  return json({ error: 'Unauthorized' }, 401);
}

// Invitee accepts or declines.
async function handleInviteeResponse(
  supabase: any,
  userId: string,
  group: any,
  invitation: any,
  body: any,
): Promise<Response> {
  if (invitation.status !== 'pending') {
    return json({ error: 'Invitation is no longer pending' }, 422);
  }

  const accepted = String(body.accepted) === 'true';

  if (accepted) {
    if (invitation.inviter_id === group.creator_id) {
      // Inviter is creator — skip approval, add to group immediately
      await supabase.from('group_invitations').update({ status: 'approved' }).eq('id', invitation.id);
      await supabase.from('group_memberships').insert({ group_id: group.id, user_id: userId });
      return json({ invitation_id: invitation.id, status: 'approved' });
    } else {
      // Inviter is not creator — notify creator to approve
      await supabase.from('group_invitations').update({ status: 'accepted' }).eq('id', invitation.id);

      const [{ data: invitee }] = await Promise.all([
        supabase.from('users').select('name').eq('id', userId).maybeSingle(),
      ]);

      await deliver({
        userIds: [group.creator_id],
        type:    'group_join_request',
        message: `${invitee?.name ?? 'Someone'} accepted an invitation to ${group.name} — awaiting your approval`,
        context: `group_${group.id}`,
      });

      return json({ invitation_id: invitation.id, status: 'accepted' });
    }
  } else {
    await supabase.from('group_invitations').update({ status: 'declined' }).eq('id', invitation.id);
    return json({ invitation_id: invitation.id, status: 'declined' });
  }
}

// Creator approves or rejects an accepted invitation.
async function handleCreatorResponse(
  supabase: any,
  group: any,
  invitation: any,
  body: any,
): Promise<Response> {
  if (invitation.status !== 'accepted') {
    return json({ error: 'Not awaiting approval' }, 422);
  }

  const approved = String(body.approved) === 'true';
  const newStatus = approved ? 'approved' : 'rejected';

  await supabase.from('group_invitations').update({ status: newStatus }).eq('id', invitation.id);

  if (approved) {
    await supabase.from('group_memberships').insert({ group_id: group.id, user_id: invitation.invitee_id });
    await deliver({
      userIds: [invitation.invitee_id],
      type:    'group_invitation_approved',
      message: `Your invitation to ${group.name} was approved — welcome to the group!`,
    });
  } else {
    await deliver({
      userIds: [invitation.invitee_id],
      type:    'group_invitation',
      message: `Your request to join ${group.name} was not approved.`,
    });
  }

  return json({ invitation_id: invitation.id, status: newStatus });
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
