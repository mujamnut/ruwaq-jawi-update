-- =====================================================
-- FIX: DUPLICATE FUNCTION ERROR - private.is_admin()
-- =====================================================
-- ERROR: function private.is_admin() is not unique
-- SOLUTION: Clean up duplicate functions dan create clean version
-- =====================================================

-- STEP 1: DIAGNOSE DUPLICATE FUNCTIONS
-- =====================================================

-- Check semua functions private.is_admin yang wujud
SELECT 
  proname as function_name,
  pg_get_function_identity_arguments(oid) as arguments,
  prosrc as function_body
FROM pg_proc 
WHERE proname = 'is_admin' 
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'private');

-- STEP 2: DROP ALL EXISTING is_admin FUNCTIONS
-- =====================================================

-- Drop semua variants function private.is_admin()
DROP FUNCTION IF EXISTS private.is_admin();
DROP FUNCTION IF EXISTS private.is_admin(uuid);
DROP FUNCTION IF EXISTS private.is_admin(text);

-- Kalau masih ada error, try drop dengan signature specific:
-- DROP FUNCTION IF EXISTS private.is_admin() CASCADE;

-- STEP 3: CREATE CLEAN ADMIN FUNCTION
-- =====================================================

-- Create private schema jika belum ada
CREATE SCHEMA IF NOT EXISTS private;

-- Create single, clean admin function
CREATE OR REPLACE FUNCTION private.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  admin_emails TEXT[] := ARRAY[
    'admin@yourapp.com',          -- 🔄 GANTI dengan admin email anda
    'kumar@yourapp.com',          -- 🔄 GANTI dengan admin email anda
    'your-admin@email.com'        -- 🔄 TAMBAH admin emails lain
  ];
BEGIN
  -- METHOD 1: Check by email (simple & reliable)
  RETURN auth.email() = ANY(admin_emails);
  
  -- METHOD 2: Check raw_app_meta_data (uncomment jika prefer ini)
  -- RETURN COALESCE(
  --   (SELECT (raw_app_meta_data->>'role') = 'admin'
  --    FROM auth.users WHERE id = auth.uid()),
  --   false
  -- );
END;
$$;

-- STEP 4: TEST FUNCTION
-- =====================================================

-- Test function works
SELECT 
  'Function Test' as test_name,
  CASE 
    WHEN private.is_admin() THEN '✅ ADMIN ACCESS'
    ELSE '❌ NOT ADMIN'
  END as result,
  auth.email() as current_email;

-- STEP 5: RECREATE POLICIES DENGAN CLEAN FUNCTION
-- =====================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Admin full access" ON public.kitab_videos;
DROP POLICY IF EXISTS "Admin full control kitab_videos" ON public.kitab_videos;
DROP POLICY IF EXISTS "Admin full access to kitab_videos" ON public.kitab_videos;
DROP POLICY IF EXISTS "Public read access" ON public.kitab_videos;
DROP POLICY IF EXISTS "Students can view published episodes" ON public.kitab_videos;

-- Ensure RLS enabled
ALTER TABLE public.kitab_videos ENABLE ROW LEVEL SECURITY;

-- Create simple admin policy
CREATE POLICY "Admin full access"
ON public.kitab_videos
FOR ALL
TO authenticated
USING (private.is_admin())
WITH CHECK (private.is_admin());

-- Create public read policy  
CREATE POLICY "Public read episodes"
ON public.kitab_videos
FOR SELECT
TO authenticated, anon
USING (
  is_active = true
  AND EXISTS (
    SELECT 1 FROM public.kitab k 
    WHERE k.id = kitab_id 
    AND k.is_active = true
  )
);

-- STEP 6: GRANT PERMISSIONS
-- =====================================================

GRANT SELECT ON public.kitab_videos TO authenticated, anon;
GRANT INSERT, UPDATE, DELETE ON public.kitab_videos TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- STEP 7: VERIFICATION TESTS
-- =====================================================

-- Test 1: Check function uniqueness
SELECT COUNT(*) as function_count
FROM pg_proc 
WHERE proname = 'is_admin' 
  AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'private');
-- Should return 1

-- Test 2: Check admin status
SELECT 
  auth.email() as email,
  private.is_admin() as is_admin;

-- Test 3: List active policies
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'kitab_videos';

-- Test 4: Test SELECT access (should work for everyone)
SELECT COUNT(*) as total_episodes FROM kitab_videos;

-- STEP 8: TEST INSERT (ADMIN ONLY)
-- =====================================================

-- Test INSERT jika anda admin (uncomment untuk test)
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
  'your-kitab-id-here',           -- 🔄 GANTI dengan kitab ID yang betul
  'Test Episode - Function Fixed',
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
-- ALTERNATIVE SOLUTIONS (JIKA MASIH ADA ISSUES)
-- =====================================================

-- OPTION A: Use different function name untuk avoid conflicts
/*
CREATE OR REPLACE FUNCTION private.check_admin_user()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN auth.email() IN (
    'admin@yourapp.com',     -- 🔄 GANTI EMAIL
    'your-admin@email.com'   -- 🔄 GANTI EMAIL
  );
END;
$$;

-- Update policies guna function name baru
CREATE POLICY "Admin full access v2"
ON public.kitab_videos
FOR ALL
TO authenticated
USING (private.check_admin_user())
WITH CHECK (private.check_admin_user());
*/

-- OPTION B: Drop dan recreate schema private completely
/*
DROP SCHEMA IF EXISTS private CASCADE;
CREATE SCHEMA private;

-- Then create function as above
*/

-- =====================================================
-- TROUBLESHOOTING TIPS
-- =====================================================

/*
COMMON CAUSES OF DUPLICATE FUNCTION ERROR:

1. Multiple CREATE FUNCTION statements dengan parameters berbeza
2. Function created dengan dan tanpa parameters
3. Function created dengan different return types
4. Remnants dari previous failed attempts

SOLUTIONS:
1. Always use CREATE OR REPLACE FUNCTION
2. Drop all variants sebelum create new one
3. Use specific function signatures dalam DROP statements
4. Check pg_proc table untuk verify cleanup

BEST PRACTICES:
1. Use email-based admin check untuk simplicity
2. Store admin emails dalam array untuk easy management  
3. Use consistent function naming conventions
4. Test function sebelum create policies
*/
