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

  try {
    const body = await req.json();
    const apiMovieId = parseInt(body.api_movie_id, 10);
    const contentType: string = body.content_type || 'movie';

    const supabase = getAdminClient();

    // Find current user's relationship (confirmed or not — matches Rails User#relationship)
    const { data: rel } = await supabase
      .from('relationships')
      .select('id, sender_id, recipient_id')
      .or(`sender_id.eq.${user.id},recipient_id.eq.${user.id}`)
      .maybeSingle();

    const partnerId: string | null = rel
      ? (rel.sender_id === user.id ? rel.recipient_id : rel.sender_id)
      : null;

    // Check if partner has already liked this title (replicates User#partner + Like.find_by)
    const { data: partnerLike } = partnerId
      ? await supabase
          .from('likes')
          .select('id')
          .eq('user_id', partnerId)
          .eq('api_movie_id', apiMovieId)
          .eq('content_type', contentType)
          .maybeSingle()
      : { data: null };

    if (partnerLike && rel) {
      // MATCH — create favorite, delete partner's like, notify both users.
      // Current user's like is intentionally never saved on a match.
      const { data: favorite, error: favError } = await supabase
        .from('favorites')
        .insert({ relationship_id: rel.id, api_movie_id: apiMovieId, content_type: contentType })
        .select()
        .single();

      if (favError || !favorite) {
        return json({ error: 'Could not create favorite' }, 400);
      }

      await supabase.from('likes').delete().eq('id', partnerLike.id);

      // Fetch both names for personalized notification messages
      const { data: usersData } = await supabase
        .from('users')
        .select('id, name')
        .in('id', [user.id, partnerId]);

      const currentUserName = usersData?.find((u: any) => u.id === user.id)?.name ?? 'Someone';
      const partnerName     = usersData?.find((u: any) => u.id === partnerId)?.name ?? 'Someone';

      // Replicates: [current_user, partner].each { |u| deliver(message: "You and {other}.name...") }
      await deliver({
        userIds: [user.id],
        type:    'partner_watchlist_match',
        message: `You and ${partnerName} matched! Check your Partner watchlist.`,
        context: 'partner',
      });
      await deliver({
        userIds: [partnerId!],
        type:    'partner_watchlist_match',
        message: `You and ${currentUserName} matched! Check your Partner watchlist.`,
        context: 'partner',
      });

      return json(favorite);
    }

    // No match — save the like for the current user
    const { data: like, error: likeError } = await supabase
      .from('likes')
      .insert({ user_id: user.id, api_movie_id: apiMovieId, content_type: contentType })
      .select()
      .single();

    if (likeError || !like) {
      return json({ error: 'Could not save like' }, 400);
    }

    return json(like);
  } catch (err) {
    console.error(err);
    return json({ error: 'Internal error' }, 500);
  }
});

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
