-- Migrate legacy preview data from video_episodes.is_preview to preview_content table
-- This ensures all existing preview data is available in the unified preview system

-- First, migrate existing preview episodes to preview_content table
INSERT INTO preview_content (
    content_type,
    content_id,
    preview_type,
    preview_description,
    is_active,
    created_at,
    updated_at
)
SELECT
    'video_episode' as content_type,
    ve.id as content_id,
    'free_trial' as preview_type,
    'Migrated from legacy preview system' as preview_description,
    ve.is_active as is_active,
    ve.created_at,
    ve.updated_at
FROM video_episodes ve
WHERE ve.is_preview = true
  AND NOT EXISTS (
    -- Only insert if not already exists in preview_content
    SELECT 1 FROM preview_content pc
    WHERE pc.content_type = 'video_episode'
      AND pc.content_id = ve.id
  );

-- Show migration results
SELECT
    COUNT(*) as total_migrated,
    'video_episodes migrated to preview_content' as description
FROM preview_content
WHERE preview_description = 'Migrated from legacy preview system';

-- Show all current preview content
SELECT
    pc.content_type,
    pc.preview_type,
    COUNT(*) as count,
    COUNT(CASE WHEN pc.is_active THEN 1 END) as active_count
FROM preview_content pc
GROUP BY pc.content_type, pc.preview_type
ORDER BY pc.content_type, pc.preview_type;