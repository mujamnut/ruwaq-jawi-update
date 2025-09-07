-- =====================================================
-- FIX: auth.email() returns NULL
-- =====================================================
-- MASALAH: SQL Editor tidak authenticated sebagai user
-- SOLUTION: Alternative admin check methods
-- =====================================================

-- STEP 1: DIAGNOSE AUTHENTICATION STATUS
-- =====================================================

-- Check current auth status
SELECT 
  auth.uid() as user_id,
  auth.email() as email,
  auth.role() as role,
  CASE 
    WHEN auth.uid() IS NULL THEN '❌ NOT AUTHENTICATED'
    WHEN auth.email() IS NULL THEN '⚠️ AUTHENTICATED BUT NO EMAIL'
    ELSE '✅ AUTHENTICATED WITH EMAIL'
  END as auth_status;

-- Check jika ada users dalam database
SELECT 
  id,
  email,
  raw_app_meta_data,
  created_at
FROM auth.users 
ORDER BY created_at DESC 
LIMIT 5;

-- STEP 2: ALTERNATIVE ADMIN CHECK METHODS
-- =====================================================

-- METHOD A: Update function untuk handle NULL email (TEMPORARY FIX)
CREATE OR REPLACE FUNCTION private.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check jika running as service role atau admin context
  IF auth.email() IS NULL AND auth.uid() IS NULL THEN
    -- Probably running as service role / postgres user
    RETURN true;
  END IF;
  
  -- Check by email jika ada
  IF auth.email() IS NOT NULL THEN
    RETURN auth.email() IN (
      'admin@yourapp.com',        -- 🔄 GANTI dengan admin email anda
      'kumar@yourapp.com',        -- 🔄 GANTI dengan admin email anda
      'your-admin@email.com'      -- 🔄 TAMBAH admin emails
    );
  END IF;
  
  -- Check by user_id jika ada (backup method)
  IF auth.uid() IS NOT NULL THEN
    RETURN EXISTS (
      SELECT 1 FROM auth.users
      WHERE id = auth.uid()
      AND email IN (
        'admin@yourapp.com',      -- 🔄 GANTI dengan admin email anda
        'kumar@yourapp.com'       -- 🔄 GANTI dengan admin email anda
      )
    );
  END IF;
  
  -- Default deny
  RETURN false;
END;
$$;

-- METHOD B: Admin check by raw_app_meta_data
CREATE OR REPLACE FUNCTION private.is_admin_by_metadata()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check by metadata role
  RETURN COALESCE(
    (SELECT (raw_app_meta_data->>'role') = 'admin'
     FROM auth.users
     WHERE id = auth.uid()),
    false
  );
END;
$$;

-- METHOD C: Hardcode specific user IDs (untuk testing)
CREATE OR REPLACE FUNCTION private.is_admin_by_uid()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Hardcode admin user IDs (get dari auth.users table)
  RETURN auth.uid() IN (
    '00000000-0000-0000-0000-000000000000'::uuid,  -- 🔄 GANTI dengan admin user ID
    '11111111-1111-1111-1111-111111111111'::uuid   -- 🔄 TAMBAH admin user IDs lain
  );
END;
$$;

-- STEP 3: TEMPORARY BYPASS UNTUK ADMIN ACCESS
-- =====================================================

-- EMERGENCY: Allow all authenticated users (TEMPORARY!)
CREATE OR REPLACE FUNCTION private.is_admin_temp()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- TEMPORARY: Allow anyone authenticated atau service role
  RETURN (auth.uid() IS NOT NULL) OR (auth.uid() IS NULL);
END;
$$;

-- Update policy untuk guna temporary function
DROP POLICY IF EXISTS "Admin full access" ON public.kitab_videos;

CREATE POLICY "Admin full access temp"
ON public.kitab_videos
FOR ALL
TO authenticated
USING (private.is_admin_temp())
WITH CHECK (private.is_admin_temp());

-- STEP 4: SET ADMIN ROLE PROPERLY
-- =====================================================

-- METHOD 1: Set admin role via raw_app_meta_data (choose admin user)
/*
-- First, check existing users dan their IDs
SELECT id, email, raw_app_meta_data FROM auth.users;

-- Then update specific user to be admin
UPDATE auth.users 
SET raw_app_meta_data = jsonb_set(
  COALESCE(raw_app_meta_data, '{}'),
  '{role}',
  '"admin"'
)
WHERE email = 'your-actual-admin@email.com';  -- 🔄 GANTI dengan admin email yang betul

-- Test admin by metadata function
SELECT 
  email,
  raw_app_meta_data,
  private.is_admin_by_metadata() as is_admin
FROM auth.users 
WHERE email = 'your-actual-admin@email.com';
*/

-- METHOD 2: Create user_profiles table untuk role management
/*
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  role TEXT DEFAULT 'student' CHECK (role IN ('admin', 'student', 'teacher')),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS untuk user_profiles
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Allow users to read own profile
CREATE POLICY "Users can read own profile" ON public.user_profiles
FOR SELECT TO authenticated
USING (auth.uid() = id);

-- Allow service role to manage profiles
CREATE POLICY "Service can manage profiles" ON public.user_profiles
FOR ALL TO service_role
USING (true);

-- Insert admin profile
INSERT INTO public.user_profiles (id, email, role)
SELECT id, email, 'admin'
FROM auth.users
WHERE email = 'your-admin@email.com'  -- 🔄 GANTI dengan admin email
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
    WHERE id = auth.uid() 
    AND role = 'admin'
    AND is_active = true
  );
END;
$$;
*/

-- STEP 5: QUICK WORKAROUND - DISABLE RLS TEMPORARILY
-- =====================================================

-- ⚠️ EMERGENCY ONLY: Disable RLS untuk allow INSERT
-- ALTER TABLE public.kitab_videos DISABLE ROW LEVEL SECURITY;

-- Add episodes...

-- ⚠️ IMPORTANT: Enable balik selepas add episodes!
-- ALTER TABLE public.kitab_videos ENABLE ROW LEVEL SECURITY;

-- STEP 6: TESTING & VERIFICATION
-- =====================================================

-- Test 1: Check auth functions availability
SELECT 
  'auth.uid()' as function_name,
  auth.uid() as result
UNION ALL
SELECT 
  'auth.email()' as function_name,
  auth.email() as result
UNION ALL
SELECT 
  'auth.role()' as function_name,
  auth.role() as result;

-- Test 2: Test different admin functions
SELECT 
  'is_admin()' as method,
  private.is_admin() as result
UNION ALL
SELECT 
  'is_admin_temp()' as method,
  private.is_admin_temp() as result;

-- Test 3: Check admin metadata (if using method 1)
-- SELECT 
--   email,
--   (raw_app_meta_data->>'role') = 'admin' as is_admin_by_metadata
-- FROM auth.users
-- WHERE email = 'your-admin@email.com';

-- STEP 7: TEST INSERT DENGAN TEMPORARY ACCESS
-- =====================================================

-- Should work dengan temporary admin function
/*
INSERT INTO public.kitab_videos (
  kitab_id,
  title,
  youtube_video_id,
  part_number,
  duration_minutes,
  is_active,
  is_preview
) VALUES (
  'your-kitab-id-here',        -- 🔄 GANTI dengan kitab ID yang betul
  'Test Episode - Auth Fixed',
  'dQw4w9WgXcQ',
  999,
  3,
  true,
  false
);
*/

-- =====================================================
-- SOLUTIONS SUMMARY
-- =====================================================

/*
PROBLEM: auth.email() returns NULL dalam SQL Editor

CAUSES:
1. SQL Editor runs as service role (not authenticated user)
2. No active user session dalam SQL context
3. Using anon key instead of authenticated session

IMMEDIATE SOLUTIONS:
1. Use private.is_admin_temp() function (allows all)
2. Temporarily disable RLS
3. Set admin via raw_app_meta_data
4. Use user_profiles table approach

LONG-TERM SOLUTIONS:
1. Implement proper user role management
2. Use service role key untuk admin operations
3. Create admin interface yang authenticated properly
4. Use app metadata atau user_profiles untuk role storage

NEXT STEPS:
1. Choose one method above dan implement
2. Test INSERT episodes
3. Setup proper admin user management
4. Re-enable proper RLS policies after testing
*/
