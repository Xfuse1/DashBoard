-- Row-Level Security policies for the `credit_ledger` table
-- Run this in the Supabase SQL Editor. This file only enables RLS and
-- creates owner-only policies; it DOES NOT create the table itself.
-- It is idempotent: it uses ALTER TABLE IF EXISTS and DROP POLICY IF EXISTS
-- so it is safe to run multiple times.

BEGIN;

-- Enable Row Level Security on the table (no-op if table missing)
ALTER TABLE IF EXISTS public.credit_ledger
  ENABLE ROW LEVEL SECURITY;

-- Remove any previous policies we may have created so the script is
-- idempotent and won't error with "policy already exists".
DROP POLICY IF EXISTS credit_ledger_select ON public.credit_ledger;
DROP POLICY IF EXISTS credit_ledger_insert ON public.credit_ledger;
DROP POLICY IF EXISTS credit_ledger_update ON public.credit_ledger;
DROP POLICY IF EXISTS credit_ledger_delete ON public.credit_ledger;

-- Allow owners to SELECT their own ledger rows
CREATE POLICY credit_ledger_select
  ON public.credit_ledger
  FOR SELECT
  USING (user_id = auth.uid());

-- Allow owners to INSERT rows where user_id matches their auth.uid()
CREATE POLICY credit_ledger_insert
  ON public.credit_ledger
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Allow owners to UPDATE rows that belong to them and ensure updated
-- rows still belong to them (WITH CHECK).
CREATE POLICY credit_ledger_update
  ON public.credit_ledger
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Allow owners to DELETE their own rows
CREATE POLICY credit_ledger_delete
  ON public.credit_ledger
  FOR DELETE
  USING (user_id = auth.uid());

COMMIT;

-- Notes:
-- - Make sure `credit_ledger` exists and has a `user_id uuid` column.
-- - If you want admins (or a service role) to access rows, create an
--   additional policy that permits access when the role is a specific
--   value or when current_setting('jwt.claims.role') = 'admin'.
-- - To allow server-side inserts from a trusted service role, use the
--   service_role key on trusted server code; do NOT embed the service
--   role key in client apps.
