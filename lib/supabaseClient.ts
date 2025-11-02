import { createClient } from '@supabase/supabase-js';

const url = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY;

if (!url || !anon) {
  // We keep the throw lazy (only when used) to keep build happy in CI.
  // eslint-disable-next-line no-console
  console.warn('Supabase URL/Anon key not found in env. Client features will be limited.');
}

export const supabase = url && anon ? createClient(url, anon) : undefined;

