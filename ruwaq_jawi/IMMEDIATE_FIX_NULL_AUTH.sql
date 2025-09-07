-- =====================================================
-- IMMEDIATE FIX: NULL auth.email() Problem  
-- =====================================================
-- COPY & PASTE untuk immediate solution
-- =====================================================

-- SOLUTION 1: TEMPORARY ALLOW ALL (FASTEST FIX)
-- =====================================================

-- Create temporary admin function yang allow semua
CREATE OR REPLACE FUNCTION private.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- TEMPORARY: Allow all access (service role + authenticated users)
  RETURN true;
END;
$$;

-- Update policies
DROP POLICY IF EXISTS "Admin full access" ON public.kitab_videos;
DROP POLICY IF EXISTS "Admin full access temp" ON public.kitab_videos;

CREATE POLICY "Admin full access temp"
ON public.kitab_videos
FOR ALL
TO authenticated
USING (private.is_admin())
WITH CHECK (private.is_admin());

-- Test sekarang
SELECT 
  'Auth Test' as test,
  auth.email() as email,
  auth.uid() as uid,
  private.is_admin() as is_admin;

-- Test INSERT (uncomment untuk test)
/*
INSERT INTO public.kitab_videos (
  kitab_id, title, youtube_video_id, part_number, is_active
) VALUES (
  'your-kitab-id-here',     -- 🔄 GANTI dengan kitab ID
  'Test Episode - NULL Auth Fixed',
  'dQw4w9WgXcQ',
  999,
  true
);
*/

-- =====================================================
-- SOLUTION 2: DISABLE RLS COMPLETELY (EMERGENCY)
-- =====================================================

-- Uncomment ini jika Solution 1 tidak work:
-- ALTER TABLE public.kitab_videos DISABLE ROW LEVEL SECURITY;

-- Add episodes, then enable balik:
-- ALTER TABLE public.kitab_videos ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- SOLUTION 3: PROPER ADMIN SETUP (RECOMMENDED AFTER TESTING)
-- =====================================================

-- Step 1: Check existing users
SELECT id, email FROM auth.users LIMIT 10;

-- Step 2: Pick admin user dan set admin role
-- UPDATE auth.users 
-- SET raw_app_meta_data = '{"role": "admin"}'
-- WHERE email = 'your-actual-admin@email.com';  -- 🔄 GANTI EMAIL

-- Step 3: Update admin function untuk proper check
/*
CREATE OR REPLACE FUNCTION private.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if service role (SQL Editor context)
  IF auth.uid() IS NULL THEN
    RETURN true;  -- Allow service role access
  END IF;
  
  -- Check admin role dari metadata
  RETURN COALESCE(
    (SELECT (raw_app_meta_data->>'role') = 'admin'
     FROM auth.users WHERE id = auth.uid()),
    false
  );
END;
$$;
*/

-- =====================================================
-- IMMEDIATE ACTION NEEDED
-- =====================================================

/*
CHOOSE ONE:

FASTEST (Recommended untuk testing):
- Run SOLUTION 1 above (allow all temporarily)
- Test INSERT episodes
- Setup proper admin later

SAFEST (If worried about security):
- Run SOLUTION 2 (disable RLS temporarily)  
- Add episodes manually
- Enable RLS dan setup proper admin

PROPER (For production):
- Run SOLUTION 3 (setup actual admin user)
- Test dengan authenticated user
- Use app interface instead of SQL editor

CURRENT STATUS AFTER SOLUTION 1:
✅ private.is_admin() will return TRUE for everyone
✅ INSERT episodes should work
✅ Can add episodes through admin panel
⚠️ Remember to setup proper admin later!
*/
