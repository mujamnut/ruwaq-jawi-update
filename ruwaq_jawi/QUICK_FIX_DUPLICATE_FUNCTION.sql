-- =====================================================
-- QUICK FIX: Duplicate Function Error
-- =====================================================
-- COPY & PASTE INI DALAM SUPABASE SQL EDITOR
-- =====================================================

-- 1. Drop semua duplicate functions
DROP FUNCTION IF EXISTS private.is_admin();
DROP FUNCTION IF EXISTS private.is_admin(uuid);
DROP FUNCTION IF EXISTS private.is_admin(text);

-- 2. Create clean function (GANTI EMAIL dengan admin email anda!)
CREATE OR REPLACE FUNCTION private.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN auth.email() IN (
    'admin@yourapp.com',        -- 🔄 GANTI dengan admin email anda
    'kumar@yourapp.com'         -- 🔄 GANTI dengan admin email anda
  );
END;
$$;

-- 3. Drop existing policies
DROP POLICY IF EXISTS "Admin full access" ON public.kitab_videos;
DROP POLICY IF EXISTS "Public read access" ON public.kitab_videos;
DROP POLICY IF EXISTS "Public read episodes" ON public.kitab_videos;

-- 4. Create clean policies
CREATE POLICY "Admin full access"
ON public.kitab_videos
FOR ALL
TO authenticated
USING (private.is_admin())
WITH CHECK (private.is_admin());

CREATE POLICY "Public read episodes"
ON public.kitab_videos
FOR SELECT
TO authenticated, anon
USING (is_active = true);

-- 5. Grant permissions
GRANT SELECT ON public.kitab_videos TO authenticated, anon;
GRANT INSERT, UPDATE, DELETE ON public.kitab_videos TO authenticated;

-- 6. Test admin access
SELECT 
  auth.email() as your_email,
  private.is_admin() as is_admin;

-- 7. Test INSERT (uncomment dan ganti kitab_id untuk test)
/*
INSERT INTO public.kitab_videos (
  kitab_id, title, youtube_video_id, part_number, is_active
) VALUES (
  'your-kitab-id-here',     -- 🔄 GANTI dengan kitab ID yang betul
  'Test Episode Fixed',
  'dQw4w9WgXcQ',
  999,
  true
);
*/

-- =====================================================
-- IMPORTANT: GANTI EMAIL dalam function dengan admin email anda!
-- =====================================================
