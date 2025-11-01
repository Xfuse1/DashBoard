-- Create employers table for company profiles
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TYPE IF NOT EXISTS public.company_plan AS ENUM ('free','starter','pro','enterprise');

CREATE TABLE IF NOT EXISTS public.employers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name_ar text,
  name_en text,
  legal_name text,
  industry text,
  company_size text,
  founded_year int,
  country text,
  city text,
  street_address text,
  website text,
  linkedin_url text,
  plan public.company_plan NOT NULL DEFAULT 'free',
  tax_id text,
  kyc_doc_url text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_employers_owner ON public.employers(owner_user_id);
