-- Auto-enable YouTube sync for all playlists
-- This migration ensures all playlists with YouTube IDs are automatically synced

-- 1. Enable auto_sync for ALL existing playlists that have YouTube playlist IDs
UPDATE video_kitab
SET
    auto_sync_enabled = true,
    updated_at = NOW()
WHERE
    youtube_playlist_id IS NOT NULL
    AND youtube_playlist_id != ''
    AND auto_sync_enabled = false;

-- 2. Create trigger to auto-enable sync for new playlists
CREATE OR REPLACE FUNCTION auto_enable_youtube_sync()
RETURNS TRIGGER AS $$
BEGIN
    -- If a playlist has a YouTube playlist ID, automatically enable sync
    IF NEW.youtube_playlist_id IS NOT NULL AND NEW.youtube_playlist_id != '' THEN
        NEW.auto_sync_enabled := true;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists (for re-running migration)
DROP TRIGGER IF EXISTS trigger_auto_enable_youtube_sync ON video_kitab;

-- Create trigger on INSERT
CREATE TRIGGER trigger_auto_enable_youtube_sync
    BEFORE INSERT ON video_kitab
    FOR EACH ROW
    EXECUTE FUNCTION auto_enable_youtube_sync();

-- 3. Also create trigger for UPDATE (if someone adds playlist_id later)
DROP TRIGGER IF EXISTS trigger_auto_enable_youtube_sync_update ON video_kitab;

CREATE TRIGGER trigger_auto_enable_youtube_sync_update
    BEFORE UPDATE ON video_kitab
    FOR EACH ROW
    WHEN (
        -- Only trigger if youtube_playlist_id changed from NULL/empty to non-empty
        (OLD.youtube_playlist_id IS NULL OR OLD.youtube_playlist_id = '')
        AND (NEW.youtube_playlist_id IS NOT NULL AND NEW.youtube_playlist_id != '')
    )
    EXECUTE FUNCTION auto_enable_youtube_sync();

-- 4. Set default value for auto_sync_enabled column (if not already set)
ALTER TABLE video_kitab
    ALTER COLUMN auto_sync_enabled SET DEFAULT true;

-- 5. Add check constraint to ensure sync is enabled for playlists
-- (Optional - uncomment if you want to enforce this at database level)
-- ALTER TABLE video_kitab
--     ADD CONSTRAINT check_youtube_sync_enabled
--     CHECK (
--         youtube_playlist_id IS NULL
--         OR youtube_playlist_id = ''
--         OR auto_sync_enabled = true
--     );

-- 6. Create helpful view for monitoring sync status
CREATE OR REPLACE VIEW v_youtube_sync_status AS
SELECT
    vk.id,
    vk.title,
    vk.youtube_playlist_id,
    vk.auto_sync_enabled,
    vk.last_synced_at,
    vk.total_videos,
    vk.is_active,
    c.name as category_name,
    CASE
        WHEN vk.last_synced_at IS NULL THEN 'Never synced'
        WHEN vk.last_synced_at < NOW() - INTERVAL '6 hours' THEN 'Due for sync'
        ELSE 'Recently synced'
    END as sync_status,
    EXTRACT(EPOCH FROM (NOW() - vk.last_synced_at)) / 3600 as hours_since_sync
FROM video_kitab vk
LEFT JOIN categories c ON vk.category_id = c.id
WHERE vk.youtube_playlist_id IS NOT NULL
ORDER BY vk.last_synced_at DESC NULLS FIRST;

-- Grant permissions
GRANT SELECT ON v_youtube_sync_status TO authenticated;

-- Add helpful comments
COMMENT ON TRIGGER trigger_auto_enable_youtube_sync ON video_kitab IS
    'Automatically enables auto_sync when a YouTube playlist ID is added';

COMMENT ON FUNCTION auto_enable_youtube_sync() IS
    'Ensures all playlists with YouTube IDs have auto_sync enabled';

COMMENT ON VIEW v_youtube_sync_status IS
    'Monitoring view for YouTube playlist sync status';

-- Log the migration
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO updated_count
    FROM video_kitab
    WHERE youtube_playlist_id IS NOT NULL
        AND youtube_playlist_id != ''
        AND auto_sync_enabled = true;

    RAISE NOTICE '✅ Auto-enable YouTube sync migration completed';
    RAISE NOTICE '📊 Total playlists with auto_sync enabled: %', updated_count;
END $$;
