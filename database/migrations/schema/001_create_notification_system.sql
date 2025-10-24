-- Migration: Create New Notification System
-- Date: 2025-09-22
-- Purpose: Replace single user_notifications table with proper 2-table notification system

-- Create notifications table (master table for notification content)
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL CHECK (type IN ('broadcast', 'personal', 'group')),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  target_type TEXT NOT NULL CHECK (target_type IN ('all', 'user', 'role')),
  target_criteria JSONB DEFAULT '{}',
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 days'),
  is_active BOOLEAN DEFAULT TRUE
);

-- Add comments for documentation
COMMENT ON TABLE notifications IS 'Master table for notification content supporting broadcast and personal notifications';
COMMENT ON COLUMN notifications.type IS 'Type of notification: broadcast (all users), personal (specific user), group (role-based)';
COMMENT ON COLUMN notifications.target_type IS 'Targeting strategy: all (everyone), user (specific user), role (by user role)';
COMMENT ON COLUMN notifications.target_criteria IS 'Additional targeting information like specific user_ids or roles';
COMMENT ON COLUMN notifications.metadata IS 'Additional data like icon, action_url, content_id, etc';

-- Create notification_reads table (tracks read status per user)
CREATE TABLE notification_reads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id UUID NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(notification_id, user_id)
);

-- Add comments
COMMENT ON TABLE notification_reads IS 'Tracks read status of notifications for each user - lazy insert approach';
COMMENT ON COLUMN notification_reads.notification_id IS 'Reference to the notification';
COMMENT ON COLUMN notification_reads.user_id IS 'User who read/unread the notification';
COMMENT ON COLUMN notification_reads.is_read IS 'Whether user has read this notification';
COMMENT ON COLUMN notification_reads.read_at IS 'Timestamp when user read the notification';

-- Create indexes for performance
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_target_type ON notifications(target_type);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX idx_notifications_active_unexpired ON notifications(is_active, expires_at) WHERE is_active = TRUE;

CREATE INDEX idx_notification_reads_user_id ON notification_reads(user_id);
CREATE INDEX idx_notification_reads_notification_id ON notification_reads(notification_id);
CREATE INDEX idx_notification_reads_user_unread ON notification_reads(user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX idx_notification_reads_user_read_at ON notification_reads(user_id, read_at DESC);

-- Enable RLS for security
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_reads ENABLE ROW LEVEL SECURITY;

-- RLS policies for notifications table
CREATE POLICY "Allow admins to read all notifications" ON notifications
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Allow students to read active notifications" ON notifications
  FOR SELECT USING (
    is_active = TRUE
    AND expires_at > NOW()
    AND (
      target_type = 'all'
      OR (target_type = 'role' AND 'student' = ANY((target_criteria->>'target_roles')::TEXT[]))
      OR (target_type = 'user' AND (target_criteria->>'user_id')::UUID = auth.uid())
    )
  );

CREATE POLICY "Allow admins to insert notifications" ON notifications
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

CREATE POLICY "Allow admins to update notifications" ON notifications
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- RLS policies for notification_reads table
CREATE POLICY "Users can read their own notification reads" ON notification_reads
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can insert their own notification reads" ON notification_reads
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own notification reads" ON notification_reads
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Admins can read all notification reads" ON notification_reads
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );