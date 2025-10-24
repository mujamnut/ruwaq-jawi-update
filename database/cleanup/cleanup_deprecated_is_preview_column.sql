-- Remove deprecated is_preview column from video_episodes table
-- This should be run AFTER the migration of legacy preview data is complete

-- First, verify that all preview data has been migrated
SELECT
    COUNT(*) as legacy_preview_count,
    'video_episodes with is_preview = true (should be 0 after migration)' as description
FROM video_episodes
WHERE is_preview = true;

-- Show current preview_content entries
SELECT
    content_type,
    COUNT(*) as preview_count
FROM preview_content
GROUP BY content_type
ORDER BY content_type;

-- Remove the deprecated is_preview column
-- WARNING: This will permanently remove the column and all its data
-- Make sure the preview migration is complete before running this
ALTER TABLE video_episodes
DROP COLUMN IF EXISTS is_preview;

-- Verify the column has been removed
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'video_episodes'
  AND table_schema = 'public'
ORDER BY ordinal_position;