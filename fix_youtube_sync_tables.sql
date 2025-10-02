-- First, check if table exists and drop if structure is wrong
DROP TABLE IF EXISTS youtube_sync_settings CASCADE;
DROP TABLE IF EXISTS youtube_sync_logs CASCADE;

-- Recreate YouTube sync logs table to track sync operations
CREATE TABLE youtube_sync_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    video_kitab_id UUID REFERENCES video_kitab(id) ON DELETE CASCADE,
    sync_type TEXT NOT NULL CHECK (sync_type IN ('manual', 'auto', 'scheduled')),
    status TEXT NOT NULL CHECK (status IN ('success', 'error', 'pending')),
    new_videos_count INTEGER DEFAULT 0,
    error_message TEXT,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for faster queries
CREATE INDEX idx_youtube_sync_logs_kitab_id ON youtube_sync_logs(video_kitab_id);
CREATE INDEX idx_youtube_sync_logs_status ON youtube_sync_logs(status);
CREATE INDEX idx_youtube_sync_logs_created_at ON youtube_sync_logs(created_at);

-- Recreate YouTube sync settings table for global configuration
CREATE TABLE youtube_sync_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    setting_key TEXT UNIQUE NOT NULL,
    setting_value TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default sync settings
INSERT INTO youtube_sync_settings (setting_key, setting_value, description)
VALUES
    ('auto_sync_enabled', 'true', 'Enable automatic YouTube sync for all playlists'),
    ('sync_interval_hours', '6', 'How often to check for new videos (in hours)'),
    ('max_videos_per_sync', '50', 'Maximum number of new videos to sync at once'),
    ('youtube_api_key', 'AIzaSyDD83zBGMED3tRk46Zqm5Kr8_mvr-n2b9U', 'YouTube Data API v3 key');

-- Create function to log sync operations
CREATE OR REPLACE FUNCTION log_youtube_sync(
    p_video_kitab_id UUID,
    p_sync_type TEXT,
    p_status TEXT,
    p_new_videos_count INTEGER DEFAULT 0,
    p_error_message TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    log_id UUID;
BEGIN
    INSERT INTO youtube_sync_logs (
        video_kitab_id,
        sync_type,
        status,
        new_videos_count,
        error_message,
        completed_at
    ) VALUES (
        p_video_kitab_id,
        p_sync_type,
        p_status,
        p_new_videos_count,
        p_error_message,
        CASE WHEN p_status != 'pending' THEN NOW() ELSE NULL END
    ) RETURNING id INTO log_id;

    RETURN log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check which playlists need syncing
CREATE OR REPLACE FUNCTION get_playlists_for_sync()
RETURNS TABLE (
    kitab_id UUID,
    title TEXT,
    youtube_playlist_id TEXT,
    last_synced_at TIMESTAMPTZ,
    auto_sync_enabled BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        vk.id,
        vk.title,
        vk.youtube_playlist_id,
        vk.last_synced_at,
        vk.auto_sync_enabled
    FROM video_kitab vk
    WHERE vk.auto_sync_enabled = true
        AND vk.youtube_playlist_id IS NOT NULL
        AND vk.is_active = true
        AND (
            vk.last_synced_at IS NULL
            OR vk.last_synced_at < NOW() - INTERVAL '6 hours'
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to update video kitab stats after sync
CREATE OR REPLACE FUNCTION update_kitab_after_sync(
    p_kitab_id UUID,
    p_new_videos_count INTEGER
) RETURNS VOID AS $$
BEGIN
    UPDATE video_kitab
    SET
        total_videos = total_videos + p_new_videos_count,
        total_duration_minutes = (
            SELECT COALESCE(SUM(duration_minutes), 0)
            FROM video_episodes
            WHERE video_kitab_id = p_kitab_id
        ),
        last_synced_at = NOW(),
        updated_at = NOW()
    WHERE id = p_kitab_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON youtube_sync_logs TO authenticated;
GRANT SELECT ON youtube_sync_settings TO authenticated;
GRANT EXECUTE ON FUNCTION log_youtube_sync TO authenticated;
GRANT EXECUTE ON FUNCTION get_playlists_for_sync TO authenticated;
GRANT EXECUTE ON FUNCTION update_kitab_after_sync TO authenticated;

-- Create RLS policies
ALTER TABLE youtube_sync_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE youtube_sync_settings ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read sync logs
CREATE POLICY "Users can view sync logs" ON youtube_sync_logs
    FOR SELECT TO authenticated
    USING (true);

-- Allow service role to manage sync logs
CREATE POLICY "Service role can manage sync logs" ON youtube_sync_logs
    FOR ALL TO service_role
    USING (true);

-- Allow users to read sync settings
CREATE POLICY "Users can view sync settings" ON youtube_sync_settings
    FOR SELECT TO authenticated
    USING (true);

-- Allow service role to manage sync settings
CREATE POLICY "Service role can manage sync settings" ON youtube_sync_settings
    FOR ALL TO service_role
    USING (true);

-- Verify tables created
SELECT
    'youtube_sync_logs' as table_name,
    COUNT(*) as columns
FROM information_schema.columns
WHERE table_name = 'youtube_sync_logs'
UNION ALL
SELECT
    'youtube_sync_settings',
    COUNT(*)
FROM information_schema.columns
WHERE table_name = 'youtube_sync_settings';

-- Show settings
SELECT * FROM youtube_sync_settings ORDER BY setting_key;
