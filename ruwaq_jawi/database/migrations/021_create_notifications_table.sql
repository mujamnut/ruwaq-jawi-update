-- Create notifications table and fix notification system structure
-- This fixes the missing notifications table that notification-triggers function needs

-- Create notifications table (main notification templates)
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('payment_success', 'content_published', 'subscription_expiring', 'admin_announcement', 'system_maintenance')),
  data JSONB DEFAULT '{}',
  action_url TEXT,
  icon TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- Update user_notifications table to have proper foreign key to notifications
-- First check if notification_id column exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_notifications'
    AND column_name = 'notification_id'
  ) THEN
    -- Add notification_id column if it doesn't exist
    ALTER TABLE user_notifications
    ADD COLUMN notification_id UUID REFERENCES notifications(id) ON DELETE CASCADE;

    -- Create index for better performance
    CREATE INDEX idx_user_notifications_notification_id ON user_notifications(notification_id);
  END IF;
END $$;

-- Enable RLS on notifications table
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies for notifications table
-- Admins can do everything
CREATE POLICY "Admins can manage notifications" ON notifications
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Users can read notifications (via user_notifications)
CREATE POLICY "Users can read notifications via user_notifications" ON notifications
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_notifications
      WHERE user_notifications.notification_id = notifications.id
      AND user_notifications.user_id = auth.uid()
    )
  );

-- Update existing user_notifications RLS policies to work with new structure
DROP POLICY IF EXISTS "Users can manage their own notifications" ON user_notifications;

CREATE POLICY "Users can view their own notifications" ON user_notifications
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can update their own notifications" ON user_notifications
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Service role can insert notifications" ON user_notifications
  FOR INSERT
  TO service_role
  WITH CHECK (true);

CREATE POLICY "Admins can manage all user notifications" ON user_notifications
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Create updated trigger function that works with new table structure
CREATE OR REPLACE FUNCTION trigger_content_published_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Only trigger for newly activated content (status changed to active)
  IF TG_OP = 'UPDATE' AND OLD.is_active = false AND NEW.is_active = true THEN
    -- Call notification-triggers edge function
    PERFORM
      net.http_post(
        url := current_setting('app.supabase_url', true) || '/functions/v1/notification-triggers',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.service_role_key', true),
          'apikey', current_setting('app.service_role_key', true)
        ),
        body := jsonb_build_object(
          'type', 'content_published',
          'data', jsonb_build_object(
            'content_type', CASE
              WHEN TG_TABLE_NAME = 'video_kitab' THEN 'video_kitab'
              WHEN TG_TABLE_NAME = 'ebooks' THEN 'ebook'
              ELSE 'unknown'
            END,
            'title', NEW.title,
            'author', COALESCE(NEW.author, 'Penulis'),
            'category', COALESCE((
              SELECT name FROM categories
              WHERE id = NEW.category_id
            ), 'Kategori Umum')
          ),
          'target_roles', ARRAY['student'],
          'target_subscription', ARRAY['active']
        )
      );
  END IF;

  -- For INSERT operations (new content published)
  IF TG_OP = 'INSERT' AND NEW.is_active = true THEN
    -- Call notification-triggers edge function
    PERFORM
      net.http_post(
        url := current_setting('app.supabase_url', true) || '/functions/v1/notification-triggers',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.service_role_key', true),
          'apikey', current_setting('app.service_role_key', true)
        ),
        body := jsonb_build_object(
          'type', 'content_published',
          'data', jsonb_build_object(
            'content_type', CASE
              WHEN TG_TABLE_NAME = 'video_kitab' THEN 'video_kitab'
              WHEN TG_TABLE_NAME = 'ebooks' THEN 'ebook'
              ELSE 'unknown'
            END,
            'title', NEW.title,
            'author', COALESCE(NEW.author, 'Penulis'),
            'category', COALESCE((
              SELECT name FROM categories
              WHERE id = NEW.category_id
            ), 'Kategori Umum')
          ),
          'target_roles', ARRAY['student'],
          'target_subscription', ARRAY['active']
        )
      );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log error but don't fail the main operation
  RAISE WARNING 'Notification trigger failed: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate triggers for content published notifications
DROP TRIGGER IF EXISTS content_published_video_kitab ON video_kitab;
CREATE TRIGGER content_published_video_kitab
  AFTER INSERT OR UPDATE ON video_kitab
  FOR EACH ROW
  EXECUTE FUNCTION trigger_content_published_notification();

DROP TRIGGER IF EXISTS content_published_ebooks ON ebooks;
CREATE TRIGGER content_published_ebooks
  AFTER INSERT OR UPDATE ON ebooks
  FOR EACH ROW
  EXECUTE FUNCTION trigger_content_published_notification();

-- Create sample notification for testing
INSERT INTO notifications (title, body, type, data, action_url, icon) VALUES (
  '🎉 Selamat Datang!',
  'Terima kasih kerana menggunakan aplikasi Maktabah Ruwaq Jawi. Nikmati kandungan pembelajaran Islam yang berkualiti.',
  'admin_announcement',
  '{"priority": "medium", "welcome_message": true}',
  '/home',
  '🎉'
) ON CONFLICT DO NOTHING;

-- Comments for documentation
COMMENT ON TABLE notifications IS 'Stores notification templates that can be sent to multiple users';
COMMENT ON TABLE user_notifications IS 'Links users to notifications they should receive, with delivery status';
COMMENT ON COLUMN user_notifications.notification_id IS 'Foreign key to notifications table';
COMMENT ON COLUMN notifications.type IS 'Type of notification: payment_success, content_published, subscription_expiring, admin_announcement, system_maintenance';
COMMENT ON COLUMN notifications.data IS 'Additional data for the notification (JSON format)';
COMMENT ON COLUMN notifications.action_url IS 'URL to navigate when notification is tapped';