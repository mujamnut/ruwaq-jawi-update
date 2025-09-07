-- =====================================================
-- EMERGENCY FIX: INSERT ERROR KITAB_VIDEOS
-- =====================================================
-- QUICK SOLUTION untuk fix INSERT episode error
-- RUN INI DALAM SUPABASE SQL EDITOR
-- =====================================================

-- OPTION 1: TEMPORARY DISABLE RLS (IMMEDIATE FIX)
-- ⚠️ WARNING: Hanya untuk emergency, enable balik lepas fix!
-- =====================================================

-- Disable RLS temporarily untuk allow INSERT
-- ALTER TABLE public.kitab_videos DISABLE ROW LEVEL SECURITY;

-- After admin add episodes, enable balik:
-- ALTER TABLE public.kitab_videos ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- OPTION 2: PROPER FIX (RECOMMENDED)
-- =====================================================

-- Step 1: Enable RLS dan drop problematic policies
ALTER TABLE public.kitab_videos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin can insert episodes" ON public.kitab_videos;
DROP POLICY IF EXISTS "Admin can update episodes" ON public.kitab_videos;  
DROP POLICY IF EXISTS "Admin can delete episodes" ON public.kitab_videos;
DROP POLICY IF EXISTS "Admin full control kitab_videos" ON public.kitab_videos;
DROP POLICY IF EXISTS "Admin full access to kitab_videos" ON public.kitab_videos;

-- Step 2: Create private schema dan admin function
CREATE SCHEMA IF NOT EXISTS private;

CREATE OR REPLACE FUNCTION private.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- SESUAIKAN: Ganti dengan admin email anda
  RETURN auth.email() IN (
    'admin@yourapp.com',
    'kumar@yourapp.com', 
    'your-admin@email.com'
  );
  
  -- ATAU gunakan raw_app_meta_data method:
  -- RETURN COALESCE(
  --   (SELECT (raw_app_meta_data->>'role') = 'admin'
  --    FROM auth.users WHERE id = auth.uid()),
  --   false
  -- );
END;
$$;

-- Step 3: Create simple admin policy
CREATE POLICY "Admin full access"
ON public.kitab_videos
FOR ALL
TO authenticated
USING ((SELECT private.is_admin()))
WITH CHECK ((SELECT private.is_admin()));

-- Step 4: Create public read policy
CREATE POLICY "Public read access"  
ON public.kitab_videos
FOR SELECT
TO authenticated, anon
USING (
  is_active = true
  AND EXISTS (
    SELECT 1 FROM public.kitab k 
    WHERE k.id = kitab_id AND k.is_active = true
  )
);

-- Step 5: Grant permissions
GRANT SELECT ON public.kitab_videos TO authenticated, anon;
GRANT INSERT, UPDATE, DELETE ON public.kitab_videos TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- =====================================================
-- OPTION 3: SET ADMIN ROLE (CHOOSE ONE)
-- =====================================================

-- METHOD A: Set admin role via raw_app_meta_data
-- 🔄 GANTI EMAIL dengan email admin anda
UPDATE auth.users 
SET raw_app_meta_data = jsonb_set(
  COALESCE(raw_app_meta_data, '{}'),
  '{role}',
  '"admin"'
)
WHERE email = 'admin@yourapp.com';  -- 🔄 GANTI EMAIL INI

-- METHOD B: Create user_profiles dan set admin (if preferred)
/*
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'student',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO public.user_profiles (id, role)
SELECT id, 'admin'
FROM auth.users
WHERE email = 'admin@yourapp.com'  -- 🔄 GANTI EMAIL INI
ON CONFLICT (id) DO UPDATE SET role = 'admin';

-- Update admin function untuk guna user_profiles
CREATE OR REPLACE FUNCTION private.is_admin()
RETURNS boolean
LANGUAGE plpgsql  
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.user_profiles 
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$;
*/

-- =====================================================
-- VERIFICATION & TESTING
-- =====================================================

-- Test 1: Check current user dan admin status
SELECT 
  auth.uid() as user_id,
  auth.email() as email,
  (SELECT private.is_admin()) as is_admin;

-- Test 2: Check RLS status
SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'kitab_videos';

-- Test 3: List active policies  
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'kitab_videos';

-- Test 4: Try SELECT (should work for everyone)
SELECT COUNT(*) as total_episodes FROM kitab_videos;

-- Test 5: Try INSERT (should work for admin only)
-- 🔄 GANTI kitab_id dengan ID kitab yang wujud
/*
INSERT INTO public.kitab_videos (
  kitab_id,
  title,
  youtube_video_id,
  youtube_video_url, 
  thumbnail_url,
  part_number,
  duration_minutes,
  is_active,
  is_preview
) VALUES (
  'existing-kitab-id-here',  -- 🔄 GANTI dengan kitab ID yang betul
  'Test Episode - Emergency Fix',
  'dQw4w9WgXcQ',
  'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
  'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
  999,
  3,
  true,
  false
);
*/

-- =====================================================
-- COMMON FIXES FOR SPECIFIC ERRORS
-- =====================================================

-- ERROR: "new row violates row-level security policy"
-- FIX: Make sure user is admin dengan run:
-- SELECT private.is_admin();  -- Should return true

-- ERROR: "permission denied for table kitab_videos"
-- FIX: Run grant statements di atas atau:
-- GRANT ALL ON public.kitab_videos TO authenticated;

-- ERROR: "function private.is_admin() does not exist" 
-- FIX: Run CREATE FUNCTION statement di atas

-- ERROR: Admin function returns false
-- FIX: Check admin email/role setting, atau guna hardcode method

-- =====================================================
-- ROLLBACK PLAN (JIKA ADA MASALAH)
-- =====================================================

-- Emergency rollback - disable RLS completely
-- ALTER TABLE public.kitab_videos DISABLE ROW LEVEL SECURITY;

-- Remove all policies
-- DROP POLICY IF EXISTS "Admin full access" ON public.kitab_videos;
-- DROP POLICY IF EXISTS "Public read access" ON public.kitab_videos;

-- Grant full access to everyone (temporary)
-- GRANT ALL ON public.kitab_videos TO authenticated, anon;

-- =====================================================
-- FINAL NOTES
-- =====================================================

/*
IMPORTANT REMINDERS:

1. GANTI EMAIL dalam function private.is_admin() dengan email admin yang betul
2. Test dengan admin user sebelum proceed
3. Kalau guna raw_app_meta_data method, make sure admin role sudah di-set
4. Untuk production, guna proper user management table instead of hardcode email
5. Monitor performance selepas enable RLS balik

STEPS TO FOLLOW:
1. Run diagnostic queries untuk check current state
2. Choose Option 2 (proper fix) atau Option 1 (emergency disable)
3. Set admin role dengan Method A atau B
4. Test INSERT dengan admin user
5. Verify policies berfungsi dengan betul
*/
