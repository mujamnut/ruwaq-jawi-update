-- Check YouTube Sync System Status

-- 1. Check if tables exist and have data
SELECT 'youtube_sync_settings' as table_name, COUNT(*) as row_count
FROM youtube_sync_settings
UNION ALL
SELECT 'youtube_sync_logs', COUNT(*)
FROM youtube_sync_logs
UNION ALL
SELECT 'video_kitab (with auto_sync_enabled)', COUNT(*)
FROM video_kitab
WHERE auto_sync_enabled = true AND youtube_playlist_id IS NOT NULL;

-- 2. Check sync settings
SELECT * FROM youtube_sync_settings ORDER BY setting_key;

-- 3. Check recent sync logs (last 10)
SELECT
    id,
    video_kitab_id,
    sync_type,
    status,
    new_videos_count,
    error_message,
    started_at,
    completed_at
FROM youtube_sync_logs
ORDER BY started_at DESC
LIMIT 10;

-- 4. Check which kitabs have auto sync enabled
SELECT
    id,
    title,
    youtube_playlist_id,
    auto_sync_enabled,
    last_synced_at,
    total_videos,
    is_active
FROM video_kitab
WHERE youtube_playlist_id IS NOT NULL
ORDER BY auto_sync_enabled DESC, last_synced_at DESC NULLS FIRST;

-- 5. Check for playlists that need syncing (hasn't been synced in 6+ hours)
SELECT * FROM get_playlists_for_sync();

-- 6. Check latest episodes added (last 20)
SELECT
    ve.id,
    ve.title,
    ve.part_number,
    vk.title as kitab_title,
    ve.created_at
FROM video_episodes ve
JOIN video_kitab vk ON ve.video_kitab_id = vk.id
ORDER BY ve.created_at DESC
LIMIT 20;
