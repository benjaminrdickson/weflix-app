import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Maps notification type strings to notification_preferences column names.
// Matches NotificationService::PREF_MAP exactly.
const PREF_MAP: Record<string, string> = {
  'friend_request':              'friend_requests',
  'friend_request_accepted':     'friend_request_accepted',
  'partner_invitation':          'partner_invitations',
  'partner_invitation_approved': 'partner_invitations',
  'partner_watchlist_match':     'partner_watchlist_matches',
  'group_invitation':            'group_invitations',
  'group_invitation_approved':   'group_invitations',
  'group_watchlist_match':       'group_watchlist_matches',
  'group_join_request':          'group_join_requests',
};

function adminClient(): SupabaseClient {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
}

// Replicates NotificationService.deliver exactly.
// userIds: array of user UUIDs to notify.
export async function deliver({
  userIds,
  type,
  message,
  context = null,
}: {
  userIds: string[];
  type: string;
  message: string;
  context?: string | null;
}) {
  const supabase = adminClient();

  for (const userId of userIds) {
    // Check notification preferences — skip if user has disabled this type.
    const prefCol = PREF_MAP[type];
    if (prefCol) {
      const { data: prefs } = await supabase
        .from('notification_preferences')
        .select(prefCol)
        .eq('user_id', userId)
        .maybeSingle();

      // If row exists and preference is explicitly false, skip.
      if (prefs && prefs[prefCol] === false) continue;
    }

    const notif = await handleGrouping(supabase, userId, type, message, context);
    if (notif) {
      await sendPush(supabase, userId, notif.message);
    }
  }
}

// Replicates NotificationService.handle_grouping.
// For watchlist match types with a context, if an unread notification of the same
// type+context exists within the last 60 seconds, update its message with a count
// instead of creating a new row.
async function handleGrouping(
  supabase: SupabaseClient,
  userId: string,
  type: string,
  message: string,
  context: string | null,
): Promise<{ message: string } | null> {
  if (isWatchlistType(type) && context) {
    const sixtySecondsAgo = new Date(Date.now() - 60_000).toISOString();

    const { data: existing } = await supabase
      .from('notifications')
      .select('id, message')
      .eq('user_id', userId)
      .eq('notification_type', type)
      .eq('context', context)
      .eq('read', false)
      .gt('created_at', sixtySecondsAgo)
      .order('created_at', { ascending: true });

    if (existing && existing.length > 0) {
      const count = existing.length + 1;
      const grouped = await buildGroupedMessage(supabase, type, context, count);

      await supabase
        .from('notifications')
        .update({ message: grouped, updated_at: new Date().toISOString() })
        .in('id', existing.map((n: any) => n.id));

      return { message: grouped };
    }
  }

  const { data: notif } = await supabase
    .from('notifications')
    .insert({ user_id: userId, notification_type: type, message, context })
    .select()
    .single();

  return notif ?? null;
}

// Replicates NotificationService.send_push.
// Only sends if the user's push token starts with "ExponentPushToken".
async function sendPush(supabase: SupabaseClient, userId: string, message: string) {
  const { data: row } = await supabase
    .from('push_tokens')
    .select('token')
    .eq('user_id', userId)
    .maybeSingle();

  const token: string | undefined = row?.token;
  if (!token?.startsWith('ExponentPushToken')) return;

  const badge = await getUnreadCount(supabase, userId);

  try {
    await fetch('https://exp.host/--/expo-push-notification/api/v2/push/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ to: token, body: message, sound: 'default', badge }),
    });
  } catch {
    // push failure must never raise — in-app notification already saved
  }
}

// Replicates NotificationService.unread_count.
// Counts unread notifications created within the last 30 days.
async function getUnreadCount(supabase: SupabaseClient, userId: string): Promise<number> {
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
  const { count } = await supabase
    .from('notifications')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('read', false)
    .gt('created_at', thirtyDaysAgo);
  return count ?? 0;
}

function isWatchlistType(type: string): boolean {
  return type === 'partner_watchlist_match' || type === 'group_watchlist_match';
}

// Replicates NotificationService.grouped_message.
// For group watchlist matches, looks up the group name from the context string "group_{id}".
async function buildGroupedMessage(
  supabase: SupabaseClient,
  type: string,
  context: string,
  count: number,
): Promise<string> {
  if (type === 'partner_watchlist_match') {
    return `${count} new matches on your Partner watchlist!`;
  }
  const groupId = context.replace('group_', '');
  const { data: group } = await supabase
    .from('groups')
    .select('name')
    .eq('id', groupId)
    .maybeSingle();
  const groupName = group?.name ?? 'your group';
  return `${count} new titles added to ${groupName}!`;
}
