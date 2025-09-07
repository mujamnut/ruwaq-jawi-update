-- =====================================================
-- QUICK ADMIN RLS SETUP - KITAB_VIDEOS
-- =====================================================
-- COPY & PASTE KE SUPABASE SQL EDITOR UNTUK ADMIN CONTROL
-- =====================================================

-- 1. Enable RLS
ALTER TABLE public.kitab_videos ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing policies
DROP POLICY IF EXISTS "Admin full control kitab_videos" ON public.kitab_videos;
DROP POLICY IF EXISTS "Public can view active episodes" ON public.kitab_videos;

-- 3. Simple admin check function
CREATE SCHEMA IF NOT EXISTS private;

CREATE OR REPLACE FUNCTION private.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- SESUAIKAN: Tukar dengan logic admin check anda
  -- Option 1: Check raw_app_meta_data
  RETURN (
    SELECT (raw_app_meta_data->>'role') = 'admin'
    FROM auth.users
    WHERE id = auth.uid()
  );
  
  -- Option 2: Check dari user_profiles table
  -- RETURN EXISTS (
  --   SELECT 1 FROM public.user_profiles 
  --   WHERE id = auth.uid() AND role = 'admin'
  -- );
END;
$$;

-- 4. ADMIN FULL ACCESS POLICY
CREATE POLICY "Admin full control kitab_videos"
ON public.kitab_videos
FOR ALL
TO authenticated
USING ((SELECT private.is_admin()))
WITH CHECK ((SELECT private.is_admin()));

-- 5. PUBLIC VIEW ACCESS (untuk students/anonymous)
CREATE POLICY "Public can view active episodes"
ON public.kitab_videos
FOR SELECT
TO authenticated, anon
USING (
  is_active = true 
  AND EXISTS (
    SELECT 1 FROM public.kitab 
    WHERE id = kitab_id AND is_active = true
  )
);

-- 6. Grant permissions
GRANT SELECT ON public.kitab_videos TO authenticated, anon;
GRANT INSERT, UPDATE, DELETE ON public.kitab_videos TO authenticated;

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Check RLS enabled
SELECT tablename, rowsecurity FROM pg_tables 
WHERE tablename = 'kitab_videos';

-- List policies
SELECT policyname, cmd FROM pg_policies 
WHERE tablename = 'kitab_videos';

-- =====================================================
-- IMPORTANT: SESUAIKAN FUNCTION private.is_admin()
-- dengan struktur database anda untuk check admin!
-- =====================================================
