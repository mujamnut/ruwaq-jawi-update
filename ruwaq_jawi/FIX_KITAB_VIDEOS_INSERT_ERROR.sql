-- =====================================================
-- FIX INSERT ERROR - KITAB_VIDEOS RLS ISSUES
-- =====================================================
-- 
-- MASALAH: Ralat menambah episode disebabkan RLS policies
-- SOLUSI: Fix policies dan permissions untuk allow INSERT
--
-- COPY & PASTE KE SUPABASE SQL EDITOR
-- =====================================================

-- STEP 1: DIAGNOSE CURRENT STATE
-- =====================================================

-- Check jika RLS enabled
SELECT 
  schemaname, 
  tablename, 
  rowsecurity,
  CASE 
    WHEN rowsecurity = true THEN '✅ RLS ENABLED'
    ELSE '❌ RLS DISABLED'
  END as rls_status
FROM pg_tables 
WHERE tablename = 'kitab_videos' 
AND schemaname = 'public';

-- List semua policies yang ada
SELECT 
  policyname,
  cmd,
  permissive,
  roles,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'kitab_videos' 
AND schemaname = 'public'
ORDER BY cmd, policyname;

-- Check permissions pada table
SELECT 
  grantee,
  privilege_type,
  is_grantable
FROM information_schema.role_table_grants 
WHERE table_name = 'kitab_videos'
ORDER BY grantee, privilege_type;

-- STEP 2: CHECK ADMIN FUNCTION
-- =====================================================

-- Test jika admin function wujud
SELECT 
  routines.routine_name,
  routines.routine_type,
  routines.security_type
FROM information_schema.routines 
WHERE routine_schema = 'private' 
AND routine_name LIKE '%admin%';

-- Test admin function return value (as current user)
-- UNCOMMENT INI UNTUK TEST:
-- SELECT 
--   auth.uid() as current_user_id,
--   CASE 
--     WHEN EXISTS(SELECT 1 FROM pg_proc WHERE proname = 'is_admin' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'private'))
--     THEN 'Function EXISTS'
--     ELSE 'Function NOT FOUND'
--   END as function_status;

-- STEP 3: EMERGENCY FIX - TEMPORARY DISABLE RLS
-- =====================================================

-- JIKA PERLUKAN ACCESS SEGERA, UNCOMMENT INI:
-- WARNING: Ini temporary sahaja, jangan guna dalam production!

-- ALTER TABLE public.kitab_videos DISABLE ROW LEVEL SECURITY;

-- STEP 4: PROPER FIX - CREATE/UPDATE POLICIES
-- =====================================================

-- Drop existing problematic policies
DROP POLICY IF EXISTS "Admin can insert episodes" ON public.kitab_videos;
DROP POLICY IF EXISTS "Admin full control kitab_videos" ON public.kitab_videos;
DROP POLICY IF EXISTS "Admin full access to kitab_videos" ON public.kitab_videos;

-- Ensure RLS is enabled
ALTER TABLE public.kitab_videos ENABLE ROW LEVEL SECURITY;

-- Create private schema if not exists
CREATE SCHEMA IF NOT EXISTS private;

-- Create simple admin check function
CREATE OR REPLACE FUNCTION private.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  -- METHOD 1: Check raw_app_meta_data
  -- Sesuaikan dengan cara anda set admin role
  RETURN COALESCE(
    (SELECT (raw_app_meta_data->>'role') = 'admin'
     FROM auth.users
     WHERE id = auth.uid()),
    false
  );
  
  -- METHOD 2: Check dari user_profiles table
  -- Uncomment ini jika ada table user_profiles
  -- RETURN EXISTS (
  --   SELECT 1 
  --   FROM public.user_profiles 
  --   WHERE id = auth.uid() 
  --   AND role = 'admin'
  --   AND is_active = true
  -- );
  
  -- METHOD 3: Hardcode admin emails (untuk testing)
  -- RETURN auth.email() IN ('admin@yourapp.com', 'another.admin@yourapp.com');
END;
$$;

-- STEP 5: CREATE PROPER POLICIES
-- =====================================================

-- Policy 1: Admin full access (semua operations)
CREATE POLICY "Admin full access"
ON public.kitab_videos
FOR ALL
TO authenticated
USING ((SELECT private.is_admin()))
WITH CHECK ((SELECT private.is_admin()));

-- Policy 2: Public read access untuk active episodes
CREATE POLICY "Public read access"
ON public.kitab_videos
FOR SELECT
TO authenticated, anon
USING (
  is_active = true 
  AND EXISTS (
    SELECT 1 
    FROM public.kitab k 
    WHERE k.id = kitab_id 
    AND k.is_active = true
  )
);

-- STEP 6: GRANT NECESSARY PERMISSIONS
-- =====================================================

-- Grant table permissions
GRANT SELECT ON public.kitab_videos TO authenticated, anon;
GRANT INSERT, UPDATE, DELETE ON public.kitab_videos TO authenticated;

-- Grant sequence permissions (untuk auto-increment IDs)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- STEP 7: SET ADMIN ROLE (CHOOSE ONE METHOD)
-- =====================================================

-- METHOD 1: Set admin via raw_app_meta_data
-- Gantikan email dengan admin email anda
/*
UPDATE auth.users 
SET raw_app_meta_data = jsonb_set(
  COALESCE(raw_app_meta_data, '{}'),
  '{role}',
  '"admin"'
)
WHERE email = 'your-admin@email.com';
*/

-- METHOD 2: Create user_profiles table dan set admin
/*
-- Create table jika belum ada
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'student' CHECK (role IN ('admin', 'student')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS untuk user_profiles
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Policy untuk user_profiles
CREATE POLICY "Users can view own profile" ON public.user_profiles
FOR SELECT TO authenticated
USING (auth.uid() = id);

-- Set admin role
INSERT INTO public.user_profiles (id, role)
SELECT id, 'admin'
FROM auth.users
WHERE email = 'your-admin@email.com'
ON CONFLICT (id) DO UPDATE SET role = 'admin';
*/

-- STEP 8: VERIFICATION TESTS
-- =====================================================

-- Test 1: Check RLS status
SELECT 
  'RLS Status' as test,
  CASE 
    WHEN rowsecurity THEN '✅ ENABLED' 
    ELSE '❌ DISABLED' 
  END as result
FROM pg_tables 
WHERE tablename = 'kitab_videos';

-- Test 2: List policies
SELECT 
  'Active Policies' as test,
  COUNT(*) || ' policies found' as result
FROM pg_policies 
WHERE tablename = 'kitab_videos';

-- Test 3: Check admin function
SELECT 
  'Admin Function' as test,
  CASE 
    WHEN EXISTS(
      SELECT 1 FROM pg_proc p 
      JOIN pg_namespace n ON p.pronamespace = n.oid 
      WHERE n.nspname = 'private' AND p.proname = 'is_admin'
    )
    THEN '✅ FUNCTION EXISTS'
    ELSE '❌ FUNCTION NOT FOUND'
  END as result;

-- Test 4: Test admin check (uncomment untuk test as admin)
-- SELECT 
--   'Admin Check' as test,
--   CASE 
--     WHEN (SELECT private.is_admin()) THEN '✅ ADMIN ACCESS'
--     ELSE '❌ NOT ADMIN'
--   END as result;

-- STEP 9: TEST INSERT (RUN AS ADMIN USER)
-- =====================================================

-- Test insert dengan sample data (uncomment untuk test)
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
  'your-kitab-id-here',
  'Test Episode',
  'test-youtube-id',
  'https://www.youtube.com/watch?v=test-youtube-id',
  'https://img.youtube.com/vi/test-youtube-id/hqdefault.jpg',
  1,
  30,
  true,
  false
);
*/

-- =====================================================
-- COMMON TROUBLESHOOTING SOLUTIONS
-- =====================================================

/*
ISSUE 1: "new row violates row-level security policy"
SOLUTION: 
- Check jika user adalah admin dengan SELECT private.is_admin();
- Verify admin role telah di-set dengan betul
- Check WITH CHECK policy dalam CREATE POLICY

ISSUE 2: "permission denied for table kitab_videos"  
SOLUTION:
- Run GRANT statements di atas
- Check table ownership
- Verify user ada dalam authenticated role

ISSUE 3: "function private.is_admin() does not exist"
SOLUTION:
- Run CREATE FUNCTION statement di atas
- Check jika private schema wujud
- Verify function permissions

ISSUE 4: Admin function returns false
SOLUTION:
- Check admin role setting dalam database
- Verify raw_app_meta_data atau user_profiles table
- Try hardcode method untuk testing

ISSUE 5: Anonymous users cannot see preview episodes
SOLUTION:
- Check policy includes 'anon' role  
- Verify is_preview = true logic
- Check parent kitab is_active = true
*/

-- =====================================================
-- QUICK TEST COMMANDS (Run as admin)
-- =====================================================

-- 1. Check current user
-- SELECT auth.uid(), auth.email();

-- 2. Check admin status  
-- SELECT private.is_admin() as is_admin;

-- 3. Test select access
-- SELECT COUNT(*) FROM kitab_videos;

-- 4. Test insert access (will show if RLS blocks it)
-- Uncomment Test INSERT di atas

-- =====================================================
-- END OF DIAGNOSTIC & FIX SCRIPT
-- =====================================================
