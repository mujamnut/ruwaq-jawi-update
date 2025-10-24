-- Check which video kitabs need auto sync setup

-- 1. Show all kitabs with YouTube playlists
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
ORDER BY auto_sync_enabled DESC, title;

-- 2. Count of kitabs by sync status
SELECT
    auto_sync_enabled,
    COUNT(*) as count
FROM video_kitab
WHERE youtube_playlist_id IS NOT NULL
GROUP BY auto_sync_enabled;

-- 3. Get playlists that need syncing NOW
SELECT * FROM get_playlists_for_sync();
