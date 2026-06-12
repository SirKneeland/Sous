// Supabase client initialization.
//
// The API connects with the SERVICE ROLE key, which bypasses Row Level Security.
// This is intentional and safe ONLY because this code runs server-side and never
// ships to clients. Never expose the service role key to the iOS app or browser.

import { createClient, type SupabaseClient } from '@supabase/supabase-js';

export function createSupabaseClient(
  url: string,
  serviceRoleKey: string,
): SupabaseClient {
  if (!url || !serviceRoleKey) {
    throw new Error(
      'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set (see .env.example)',
    );
  }
  return createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
