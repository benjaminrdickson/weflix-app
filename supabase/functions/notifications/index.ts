import { corsHeaders } from '../_shared/cors.ts';
import { getUser, getAdminClient } from '../_shared/auth.ts';

const PREFERENCE_COLUMNS = [
  'friend_requests',
  'friend_request_accepted',
  'partner_invitations',
  'partner_watchlist_matches',
  'group_invitations',
  'group_watchlist_matches',
  'group_join_requests',
] as const;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  const user = await getUser(req);
  if (!user) return json({ error: 'Unauthorized' }, 401);

  const url  = new URL(req.url);
  const path = url.pathname;

  // Route to notification preferences sub-resource
  if (/\/notifications\/preferences/.test(path)) {
    if (req.method === 'GET')   return await handlePreferencesShow(user.id);
    if (req.method === 'PATCH') return await handlePreferencesUpdate(user.id, req);
    return json({ error: 'Method not allowed' }, 405);
  }

  try {
    // Check named sub-routes before numeric :id to avoid false matches
    if (req.method === 'PATCH'  && /\/notifications\/mark_all_read/.test(path)) return await handleMarkAllRead(user.id);
    if (req.method === 'DELETE' && /\/notifications\/clear_all/.test(path))     return await handleClearAll(user.id);

    const idMatch = path.match(/\/notifications\/(\d+)/);
    const notifId = idMatch ? parseInt(idMatch[1], 10) : null;

    if (req.method === 'GET')             return await handleIndex(user.id);
    if (req.method === 'PATCH' && notifId) return await handleUpdate(user.id, notifId);

    return json({ error: 'Method not allowed' }, 405);
  } catch (err) {
    console.error(err);
    return json({ error: 'Internal error' }, 500);
  }
});

// Replicates NotificationsController#index.
// Deletes notifications older than 30 days, then returns remaining recent ones desc.
async function handleIndex(userId: string): Promise<Response> {
  const supabase = getAdminClient();
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();

  await supabase
    .from('notifications')
    .delete()
    .eq('user_id', userId)
    .lte('created_at', thirtyDaysAgo);

  const { data: notifications } = await supabase
    .from('notifications')
    .select('id, notification_type, message, read, context, created_at')
    .eq('user_id', userId)
    .gt('created_at', thirtyDaysAgo)
    .order('created_at', { ascending: false });

  return json(notifications ?? []);
}

// Replicates NotificationsController#update — marks a single notification read.
async function handleUpdate(userId: string, notifId: number): Promise<Response> {
  const supabase = getAdminClient();

  const { data: notif } = await supabase
    .from('notifications')
    .select('id, notification_type, message, read, context, created_at')
    .eq('id', notifId)
    .eq('user_id', userId)
    .maybeSingle();

  if (!notif) return json({ error: 'Not found' }, 404);

  const { data: updated } = await supabase
    .from('notifications')
    .update({ read: true })
    .eq('id', notifId)
    .select('id, notification_type, message, read, context, created_at')
    .single();

  return json(updated);
}

// Replicates NotificationsController#mark_all_read.
// Only marks recent (last 30 days) unread notifications.
async function handleMarkAllRead(userId: string): Promise<Response> {
  const supabase = getAdminClient();
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();

  await supabase
    .from('notifications')
    .update({ read: true })
    .eq('user_id', userId)
    .eq('read', false)
    .gt('created_at', thirtyDaysAgo);

  return json({ message: 'All notifications marked as read' });
}

// Replicates NotificationsController#clear_all — deletes ALL notifications (not just recent).
async function handleClearAll(userId: string): Promise<Response> {
  const supabase = getAdminClient();
  await supabase.from('notifications').delete().eq('user_id', userId);
  return json({ message: 'All notifications cleared' });
}

// Replicates NotificationPreferencesController#show.
// Returns all-true defaults if no row exists (trigger should always create one).
async function handlePreferencesShow(userId: string): Promise<Response> {
  const supabase = getAdminClient();

  const { data: prefs } = await supabase
    .from('notification_preferences')
    .select(PREFERENCE_COLUMNS.join(', '))
    .eq('user_id', userId)
    .maybeSingle();

  return json(serializePrefs(prefs));
}

// Replicates NotificationPreferencesController#update.
// Only allows updating the 7 known preference columns.
async function handlePreferencesUpdate(userId: string, req: Request): Promise<Response> {
  const supabase = getAdminClient();
  const body = await req.json();

  const updates: Record<string, boolean> = {};
  for (const col of PREFERENCE_COLUMNS) {
    if (typeof body[col] === 'boolean') {
      updates[col] = body[col];
    }
  }

  const { data: updated } = await supabase
    .from('notification_preferences')
    .update(updates)
    .eq('user_id', userId)
    .select(PREFERENCE_COLUMNS.join(', '))
    .single();

  return json(serializePrefs(updated));
}

// Replicates NotificationPreferencesController#serialize.
// Returns true for any column that is null (matches Rails nil? ? true : value behaviour).
function serializePrefs(prefs: any): Record<string, boolean> {
  const result: Record<string, boolean> = {};
  for (const col of PREFERENCE_COLUMNS) {
    result[col] = prefs?.[col] ?? true;
  }
  return result;
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
