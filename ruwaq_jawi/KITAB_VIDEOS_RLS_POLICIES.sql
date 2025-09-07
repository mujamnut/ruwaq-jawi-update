-- =====================================================
-- ROW LEVEL SECURITY POLICIES FOR KITAB_VIDEOS TABLE
-- =====================================================
-- 
-- TUJUAN: Membuat policies supaya ADMIN BOLEH KAWAL SEMUA access
-- kepada table kitab_videos dengan RLS yang secure dan flexible
--
-- COPY & PASTE KE SUPABASE SQL EDITOR
-- =====================================================

-- 1. ENABLE RLS PADA TABLE KITAB_VIDEOS
-- =====================================================
ALTER TABLE public.kitab_videos ENABLE ROW LEVEL SECURITY;

-- 2. DROP EXISTING POLICIES (JIKA ADA) 
-- =====================================================
DROP POLICY IF EXISTS "Admin full access to kitab_videos" ON public.kitab_videos;
DROP POLICY IF EXISTS "Students can view published episodes" ON public.kitab_videos;
DROP POLICY IF EXISTS "Premium students can view premium episodes" ON public.kitab_videos;
DROP POLICY IF EXISTS "Preview episodes visible to all" ON public.kitab_videos;

-- 3. HELPER FUNCTION UNTUK CHECK USER ROLE
-- =====================================================
-- Buat schema private jika belum ada
CREATE SCHEMA IF NOT EXISTS private;

-- Function untuk check jika user adalah admin
CREATE OR REPLACE FUNCTION private.is_admin(user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  -- Check dari table user_profiles atau auth.users metadata
  -- Sesuaikan dengan struktur database anda
  
  -- Option 1: Jika ada column 'role' dalam table user_profiles
  RETURN EXISTS (
    SELECT 1 
    FROM public.user_profiles 
    WHERE id = user_id 
    AND role = 'admin'
    AND is_active = true
  );
  
  -- Option 2: Jika guna raw_app_meta_data dalam auth.users
  -- RETURN (
  --   SELECT (raw_app_meta_data->>'role') = 'admin'
  --   FROM auth.users
  --   WHERE id = user_id
  -- );
  
  -- Option 3: Jika ada table admins berasingan
  -- RETURN EXISTS (
  --   SELECT 1
  --   FROM public.admins
  --   WHERE user_id = user_id
  --   AND is_active = true
  -- );
  
END;
$$;

-- Function untuk check jika user ada subscription aktif
CREATE OR REPLACE FUNCTION private.has_active_subscription(user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.user_subscriptions
    WHERE user_id = $1
    AND is_active = true
    AND (expires_at IS NULL OR expires_at > now())
  );
END;
$$;

-- Function untuk check jika kitab boleh diakses oleh user
CREATE OR REPLACE FUNCTION private.can_access_kitab(kitab_id text, user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  -- Check jika kitab adalah premium
  IF EXISTS (
    SELECT 1
    FROM public.kitab
    WHERE id = kitab_id
    AND is_premium = true
  ) THEN
    -- Kalau premium, kena ada subscription
    RETURN private.has_active_subscription(user_id);
  ELSE
    -- Kalau free, semua boleh akses
    RETURN true;
  END IF;
END;
$$;

-- 4. MAIN RLS POLICIES UNTUK KITAB_VIDEOS
-- =====================================================

-- POLICY 1: ADMIN FULL ACCESS
-- Admin boleh buat/baca/update/delete semua episodes
CREATE POLICY "Admin full access to kitab_videos"
ON public.kitab_videos
FOR ALL
TO authenticated
USING ((SELECT private.is_admin()))
WITH CHECK ((SELECT private.is_admin()));

-- POLICY 2: STUDENTS BOLEH VIEW PUBLISHED EPISODES SAHAJA
-- Untuk episodes yang published dan active
CREATE POLICY "Students can view published episodes"
ON public.kitab_videos
FOR SELECT
TO authenticated, anon
USING (
  is_active = true
  AND NOT is_preview = false  -- Bukan preview episodes
  AND EXISTS (
    -- Check kitab exist dan active
    SELECT 1
    FROM public.kitab k
    WHERE k.id = kitab_id
    AND k.is_active = true
  )
  AND (
    -- Jika episode free OR user ada subscription untuk premium content
    NOT EXISTS (
      SELECT 1
      FROM public.kitab k
      WHERE k.id = kitab_id
      AND k.is_premium = true
    )
    OR private.can_access_kitab(kitab_id, auth.uid())
  )
);

-- POLICY 3: PREVIEW EPISODES VISIBLE TO ALL
-- Episodes preview boleh dilihat tanpa subscription
CREATE POLICY "Preview episodes visible to all"
ON public.kitab_videos
FOR SELECT
TO authenticated, anon
USING (
  is_active = true
  AND is_preview = true
  AND EXISTS (
    SELECT 1
    FROM public.kitab k
    WHERE k.id = kitab_id
    AND k.is_active = true
  )
);

-- 5. POLICY UNTUK INSERT/UPDATE/DELETE (ADMIN SAHAJA)
-- =====================================================

-- Hanya admin boleh insert episodes
CREATE POLICY "Admin can insert episodes"
ON public.kitab_videos
FOR INSERT
TO authenticated
WITH CHECK ((SELECT private.is_admin()));

-- Hanya admin boleh update episodes  
CREATE POLICY "Admin can update episodes"
ON public.kitab_videos
FOR UPDATE
TO authenticated
USING ((SELECT private.is_admin()))
WITH CHECK ((SELECT private.is_admin()));

-- Hanya admin boleh delete episodes
CREATE POLICY "Admin can delete episodes"
ON public.kitab_videos
FOR DELETE
TO authenticated
USING ((SELECT private.is_admin()));

-- 6. GRANT PERMISSIONS PADA ROLES
-- =====================================================

-- Grant select untuk authenticated users
GRANT SELECT ON public.kitab_videos TO authenticated;

-- Grant select untuk anonymous users (untuk preview)
GRANT SELECT ON public.kitab_videos TO anon;

-- Grant insert/update/delete untuk authenticated (akan dikawal oleh RLS)
GRANT INSERT, UPDATE, DELETE ON public.kitab_videos TO authenticated;

-- 7. OPTIONAL: POLICIES UNTUK SPECIFIC USE CASES
-- =====================================================

-- POLICY: Admin boleh access inactive episodes (untuk preview)
CREATE POLICY "Admin can view inactive episodes"
ON public.kitab_videos
FOR SELECT
TO authenticated
USING (
  (SELECT private.is_admin()) 
  AND is_active = false
);

-- POLICY: Students boleh view statistics (view count etc) untuk analytics
-- CREATE POLICY "Students can view episode stats"
-- ON public.kitab_videos
-- FOR SELECT
-- TO authenticated
-- USING (
--   -- Hanya columns tertentu dan hanya untuk published episodes
--   is_active = true
--   AND private.can_access_kitab(kitab_id, auth.uid())
-- );

-- 8. TEST QUERIES (OPTIONAL - UNTUK VERIFY)
-- =====================================================

-- Test 1: Admin boleh tengok semua
-- SELECT * FROM kitab_videos; -- As admin

-- Test 2: User biasa hanya nampak yang published dan ada access
-- SELECT * FROM kitab_videos; -- As normal user  

-- Test 3: Anonymous user hanya nampak preview
-- SELECT * FROM kitab_videos WHERE is_preview = true; -- As anonymous

-- =====================================================
-- NOTES & CONFIGURATION
-- =====================================================

/*
IMPORTANT CONFIGURATION NOTES:

1. SESUAIKAN HELPER FUNCTIONS:
   - private.is_admin(): Sesuaikan dengan struktur table user/admin anda
   - private.has_active_subscription(): Sesuaikan dengan table subscription
   - private.can_access_kitab(): Sesuaikan dengan business logic premium

2. TABLE STRUCTURE DEPENDENCIES:
   - public.user_profiles (jika guna option 1 untuk admin check)
   - public.user_subscriptions (untuk premium access)
   - public.kitab (parent table)

3. CUSTOM MODIFICATIONS:
   - Tukar logic premium access sesuai keperluan
   - Tambah/kurang policies sesuai business rules
   - Sesuaikan roles (authenticated/anon) mengikut keperluan

4. TESTING:
   - Test dengan different user roles
   - Verify admin access berfungsi
   - Check anonymous user restrictions
   - Test premium content access

5. PERFORMANCE OPTIMIZATION:
   - Add indexes pada columns yang digunakan dalam policies:
   
   CREATE INDEX IF NOT EXISTS idx_kitab_videos_active 
   ON kitab_videos (is_active);
   
   CREATE INDEX IF NOT EXISTS idx_kitab_videos_preview 
   ON kitab_videos (is_preview);
   
   CREATE INDEX IF NOT EXISTS idx_kitab_videos_kitab_id 
   ON kitab_videos (kitab_id);

6. MONITORING:
   - Monitor policy performance
   - Check logs untuk access violations
   - Review policies berkala untuk security
*/

-- =====================================================
-- VERIFICATION SCRIPTS
-- =====================================================

-- Check RLS is enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'kitab_videos' 
AND schemaname = 'public';

-- List all policies on table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'kitab_videos' 
AND schemaname = 'public';

-- =====================================================
-- END OF SQL SCRIPT
-- =====================================================
