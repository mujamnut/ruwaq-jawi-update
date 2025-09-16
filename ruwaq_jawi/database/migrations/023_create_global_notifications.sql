-- Create global notifications table for messages targeting all students
-- This is more efficient than creating individual records for each user

CREATE TABLE global_notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

  -- Message content
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT NOT NULL, -- 'new_content', 'announcement', 'maintenance', etc.

  -- Metadata
  metadata JSONB DEFAULT '{}',

  -- Targeting
  target_roles TEXT[] DEFAULT ARRAY['student'], -- ['student', 'admin'] etc
  target_criteria JSONB DEFAULT '{}', -- Additional filters

  -- Status
  is_active BOOLEAN DEFAULT true,

  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE, -- Optional expiry

  -- Content reference (for video notifications)
  content_type TEXT, -- 'video_kitab', 'video_episode', 'ebook'
  content_id UUID, -- Reference to the actual content

  -- Priority
  priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent'))
);

-- Indexes
CREATE INDEX idx_global_notifications_active ON global_notifications(is_active);
CREATE INDEX idx_global_notifications_created_at ON global_notifications(created_at DESC);
CREATE INDEX idx_global_notifications_target_roles ON global_notifications USING GIN(target_roles);
CREATE INDEX idx_global_notifications_expires_at ON global_notifications(expires_at) WHERE expires_at IS NOT NULL;

-- User read status tracking table
CREATE TABLE user_notification_reads (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  global_notification_id UUID NOT NULL REFERENCES global_notifications(id) ON DELETE CASCADE,
  read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  UNIQUE(user_id, global_notification_id)
);

-- Indexes for read tracking
CREATE INDEX idx_user_notification_reads_user_id ON user_notification_reads(user_id);
CREATE INDEX idx_user_notification_reads_notification_id ON user_notification_reads(global_notification_id);

-- Function to get unread notifications for a user
CREATE OR REPLACE FUNCTION get_unread_notifications_for_user(user_uuid UUID, user_role TEXT DEFAULT 'student')
RETURNS TABLE (
  id UUID,
  title TEXT,
  message TEXT,
  type TEXT,
  metadata JSONB,
  priority TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  content_type TEXT,
  content_id UUID
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    gn.id,
    gn.title,
    gn.message,
    gn.type,
    gn.metadata,
    gn.priority,
    gn.created_at,
    gn.content_type,
    gn.content_id
  FROM global_notifications gn
  WHERE gn.is_active = true
    AND (gn.expires_at IS NULL OR gn.expires_at > NOW())
    AND user_role = ANY(gn.target_roles)
    AND NOT EXISTS (
      SELECT 1 FROM user_notification_reads unr
      WHERE unr.user_id = user_uuid
      AND unr.global_notification_id = gn.id
    )
  ORDER BY
    CASE gn.priority
      WHEN 'urgent' THEN 1
      WHEN 'high' THEN 2
      WHEN 'normal' THEN 3
      WHEN 'low' THEN 4
    END,
    gn.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark notification as read
CREATE OR REPLACE FUNCTION mark_notification_as_read(user_uuid UUID, notification_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  INSERT INTO user_notification_reads (user_id, global_notification_id)
  VALUES (user_uuid, notification_uuid)
  ON CONFLICT (user_id, global_notification_id) DO NOTHING;

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get notification stats
CREATE OR REPLACE FUNCTION get_notification_stats(notification_uuid UUID)
RETURNS TABLE (
  total_students INTEGER,
  read_count INTEGER,
  unread_count INTEGER,
  read_percentage NUMERIC(5,2)
) AS $$
BEGIN
  RETURN QUERY
  WITH stats AS (
    SELECT
      (SELECT COUNT(*) FROM profiles WHERE role = 'student') as total_students,
      (SELECT COUNT(*) FROM user_notification_reads WHERE global_notification_id = notification_uuid) as read_count
  )
  SELECT
    s.total_students::INTEGER,
    s.read_count::INTEGER,
    (s.total_students - s.read_count)::INTEGER as unread_count,
    CASE
      WHEN s.total_students > 0 THEN (s.read_count::NUMERIC / s.total_students::NUMERIC * 100)::NUMERIC(5,2)
      ELSE 0::NUMERIC(5,2)
    END as read_percentage
  FROM stats s;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT SELECT ON global_notifications TO authenticated;
GRANT SELECT, INSERT ON user_notification_reads TO authenticated;
GRANT EXECUTE ON FUNCTION get_unread_notifications_for_user(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION mark_notification_as_read(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_notification_stats(UUID) TO authenticated;

-- Comments
COMMENT ON TABLE global_notifications IS 'Global notifications that target multiple users efficiently';
COMMENT ON TABLE user_notification_reads IS 'Tracks which users have read which global notifications';
COMMENT ON FUNCTION get_unread_notifications_for_user(UUID, TEXT) IS 'Gets unread notifications for a specific user';
COMMENT ON FUNCTION mark_notification_as_read(UUID, UUID) IS 'Marks a notification as read for a user';
COMMENT ON FUNCTION get_notification_stats(UUID) IS 'Gets read/unread statistics for a notification';