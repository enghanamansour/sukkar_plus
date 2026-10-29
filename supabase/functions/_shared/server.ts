// Shared server helpers for Adeed Edge Functions (Deno).
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0';

export const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGIN') ?? '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Vary': 'Origin',
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json; charset=utf-8' } });
}

export function fail(status: number, code: string, message: string, extra: Record<string, unknown> = {}): Response {
  return json({ error: { code, message, ...extra } }, status);
}

function pickKey(jsonVar: string, legacyVar: string): string {
  const raw = Deno.env.get(jsonVar);
  if (raw) {
    try {
      const parsed = JSON.parse(raw) as Record<string, string>;
      if (parsed.default) return parsed.default;
      const first = Object.values(parsed)[0];
      if (first) return first;
    } catch { /* fall through */ }
  }
  const legacy = Deno.env.get(legacyVar);
  if (!legacy) throw new Error(`Missing ${jsonVar}/${legacyVar}`);
  return legacy;
}

const URL_ = () => Deno.env.get('SUPABASE_URL')!;

/** Admin client (bypasses RLS). Only ever used with an explicit, verified user_id filter. */
export function adminClient(): SupabaseClient {
  return createClient(URL_(), pickKey('SUPABASE_SECRET_KEYS', 'SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export interface AuthContext { userId: string; email: string | null; userClient: SupabaseClient; admin: SupabaseClient }

/**
 * Verifies the caller's Supabase session token and returns a client that acts *as that user*
 * (so Postgres Row Level Security applies to every query it makes).
 */
export async function authenticate(req: Request): Promise<AuthContext | Response> {
  const header = req.headers.get('Authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (!token) return fail(401, 'unauthenticated', 'Sign in required.');
  const userClient = createClient(URL_(), pickKey('SUPABASE_PUBLISHABLE_KEYS', 'SUPABASE_ANON_KEY'), {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await userClient.auth.getUser(token);
  if (error || !data?.user) return fail(401, 'unauthenticated', 'Your session has expired. Please sign in again.');
  return { userId: data.user.id, email: data.user.email ?? null, userClient, admin: adminClient() };
}

export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function readJson<T>(req: Request, maxBytes = 32_000): Promise<T | null> {
  const text = await req.text();
  if (text.length > maxBytes) return null;
  try { return JSON.parse(text) as T; } catch { return null; }
}
