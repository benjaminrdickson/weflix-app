import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Verifies the Supabase Bearer JWT from the Authorization header.
// Returns the authenticated user, or null if missing/invalid.
export async function getUser(req: Request) {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return null;

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error } = await supabase.auth.getUser();
  if (error || !user) return null;
  return user;
}

// Creates a service-role Supabase client that bypasses RLS.
// Use for writes that affect other users (notifications, match detection, etc.).
export function getAdminClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
}
