// Deno-only helpers (not imported by the Node tests).
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';

export function env(name: string): string | undefined {
  const v = Deno.env.get(name);
  return v && v.trim().length ? v.trim() : undefined;
}

/** Client acting as the calling user (RLS applies). */
export function userClient(req: Request): SupabaseClient | null {
  const auth = req.headers.get('authorization');
  if (!auth) return null;
  return createClient(env('SUPABASE_URL')!, env('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: auth } },
    auth: { persistSession: false },
  });
}

/** Privileged client. Used only for integration_events and minimal reads. */
export function serviceClient(): SupabaseClient {
  return createClient(env('SUPABASE_URL')!, env('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false } });
}

export async function requireUser(client: SupabaseClient | null) {
  if (!client) return null;
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) return null;
  return data.user;
}
