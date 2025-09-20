-- Script untuk fix missing thumbnails dari auto form YouTube (CORRECTED VERSION)
-- Jalankan script ini untuk auto-generate thumbnail URLs

-- 1. UNTUK video_episodes table - generate thumbnails untuk episodes yang missing
-- (Ini yang paling penting sebab video_episodes ada youtube_video_id column)
UPDATE video_episodes
SET thumbnail_url = 'https://img.youtube.com/vi/' || youtube_video_id || '/hqdefault.jpg',
    updated_at = NOW()
WHERE (thumbnail_url IS NULL OR thumbnail_url = '')
  AND youtube_video_id IS NOT NULL
  AND youtube_video_id != '';

-- 2. UNTUK video_kitab table - update thumbnail based on first episode thumbnail
-- (video_kitab tiada youtube_video_id column, jadi ambil dari first episode)
UPDATE video_kitab
SET thumbnail_url = (
    SELECT 'https://img.youtube.com/vi/' || ve.youtube_video_id || '/maxresdefault.jpg'
    FROM video_episodes ve
    WHERE ve.video_kitab_id = video_kitab.id
      AND ve.youtube_video_id IS NOT NULL
      AND ve.youtube_video_id != ''
    ORDER BY ve.part_number ASC
    LIMIT 1
),
updated_at = NOW()
WHERE (thumbnail_url IS NULL OR thumbnail_url = '')
  AND EXISTS (
    SELECT 1 FROM video_episodes ve
    WHERE ve.video_kitab_id = video_kitab.id
      AND ve.youtube_video_id IS NOT NULL
      AND ve.youtube_video_id != ''
  );

-- 3. Create function untuk auto-generate thumbnail URLs (untuk future records)
CREATE OR REPLACE FUNCTION auto_generate_thumbnail_url()
RETURNS TRIGGER AS $$
BEGIN
  -- For video_episodes table only (yang ada youtube_video_id)
  IF TG_TABLE_NAME = 'video_episodes' THEN
    -- If thumbnail_url is null but youtube_video_id exists
    IF (NEW.thumbnail_url IS NULL OR NEW.thumbnail_url = '') AND NEW.youtube_video_id IS NOT NULL AND NEW.youtube_video_id != '' THEN
      NEW.thumbnail_url := 'https://img.youtube.com/vi/' || NEW.youtube_video_id || '/hqdefault.jpg';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Create triggers untuk auto-generate thumbnails pada INSERT/UPDATE
DROP TRIGGER IF EXISTS auto_thumbnail_episodes ON video_episodes;
CREATE TRIGGER auto_thumbnail_episodes
  BEFORE INSERT OR UPDATE ON video_episodes
  FOR EACH ROW
  EXECUTE FUNCTION auto_generate_thumbnail_url();

-- 5. Test queries untuk check hasil
-- Check video_episodes
SELECT
  title,
  youtube_video_id,
  thumbnail_url,
  CASE
    WHEN thumbnail_url IS NOT NULL AND thumbnail_url != '' THEN '✅ HAS THUMBNAIL'
    WHEN youtube_video_id IS NOT NULL AND youtube_video_id != '' THEN '⚠️ MISSING THUMBNAIL (CAN AUTO-FIX)'
    ELSE '❌ NO YOUTUBE ID'
  END as status
FROM video_episodes
ORDER BY created_at DESC
LIMIT 10;

-- Check video_kitab
SELECT
  title,
  thumbnail_url,
  CASE
    WHEN thumbnail_url IS NOT NULL AND thumbnail_url != '' THEN '✅ HAS THUMBNAIL'
    ELSE '❌ MISSING THUMBNAIL'
  END as status,
  (SELECT COUNT(*) FROM video_episodes WHERE video_kitab_id = video_kitab.id) as total_episodes
FROM video_kitab
ORDER BY created_at DESC
LIMIT 10;