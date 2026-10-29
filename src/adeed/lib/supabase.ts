import { createClient } from '@supabase/supabase-js';

/**
 * Browser Supabase client. Only the project URL and the *publishable* key are used here — both are safe to
 * ship to browsers because every table is protected by Row Level Security. Secret keys and the AI provider
 * keys live only in Edge Function secrets.
 */
const url = (import.meta.env.VITE_SUPABASE_URL as string | undefined)?.trim();
const key = (import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined)?.trim();

export const supabaseConfigured = Boolean(url && key);

export const supabase = createClient(url || 'https://invalid.localhost', key || 'missing-key', {
  auth: { persistSession: true, autoRefreshToken: true, storageKey: 'adeed.auth' },
});
