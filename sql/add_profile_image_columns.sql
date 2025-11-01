-- Add profile image URL columns to tables
-- Run these against your Supabase/Postgres database (e.g. via SQL editor)

-- If your app uses `seeker_profiles` (the client references this), add column:
ALTER TABLE IF EXISTS public.seeker_profiles
  ADD COLUMN IF NOT EXISTS profile_image_url text;

-- If you also maintain the legacy `seekers` table, add a column there as well:
ALTER TABLE IF EXISTS public.seekers
  ADD COLUMN IF NOT EXISTS profile_image_url text;

-- For employers (company logos):
ALTER TABLE IF EXISTS public.employers
  ADD COLUMN IF NOT EXISTS logo_url text;

-- Notes:
-- 1) Create a Supabase Storage bucket (e.g. named `profile-images`) and
--    ensure your app's anon/public key can upload to it. You can make files
--    public or generate signed URLs depending on your needs.
-- 2) If you use Row Level Security (RLS), ensure policies allow the
--    authenticated user to INSERT/UPDATE their own profile_image_url (or
--    provide a server function to perform uploads and updates).
