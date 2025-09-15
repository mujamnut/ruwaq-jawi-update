-- Simple Notification System Setup
-- Copy paste this into Supabase SQL Editor

-- 1. Create simple admin announcement function (direct insert to user_notifications)
CREATE OR REPLACE FUNCTION send_admin_announcement_direct(
  announcement_title TEXT,
  announcement_message TEXT,
  announcement_priority TEXT DEFAULT 'medium'
)
RETURNS jsonb AS $admin_direct$
DECLARE
  notification_count INTEGER := 0;
  user_record RECORD;
  notification_message TEXT;
  notification_metadata JSONB;
BEGIN
  -- Create message and metadata
  notification_message := announcement_title || E'\n' || announcement_message;
  notification_metadata := jsonb_build_object(
    'title', announcement_title,
    'body', announcement_message,
    'type', 'admin_announcement',
    'icon', CASE
      WHEN announcement_priority = 'high' THEN '🚨'
      WHEN announcement_priority = 'medium' THEN '📢'
      ELSE 'ℹ️'
    END,
    'action_url', '/notifications',
    'data', jsonb_build_object('priority', announcement_priority, 'admin_message', true),
    'created_at', NOW()::text
  );

  -- Insert notification for all students
  INSERT INTO user_notifications (
    user_id,
    message,
    metadata,
    status,
    delivery_status,
    delivered_at
  )
  SELECT
    id,
    notification_message,
    notification_metadata,
    'unread',
    'delivered',
    NOW()
  FROM profiles
  WHERE role = 'student';

  GET DIAGNOSTICS notification_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'success', true,
    'notifications_sent', notification_count,
    'message', 'Admin announcement sent to ' || notification_count || ' students'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$admin_direct$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create simple content published notification trigger
CREATE OR REPLACE FUNCTION trigger_content_published_direct()
RETURNS TRIGGER AS $trigger_direct$
DECLARE
  notification_count INTEGER := 0;
  notification_message TEXT;
  notification_metadata JSONB;
  content_type_text TEXT;
  content_icon TEXT;
BEGIN
  -- Only trigger for newly activated content
  IF (TG_OP = 'UPDATE' AND OLD.is_active = false AND NEW.is_active = true) OR
     (TG_OP = 'INSERT' AND NEW.is_active = true) THEN

    -- Determine content type and icon
    IF TG_TABLE_NAME = 'video_kitab' THEN
      content_type_text := 'Kitab Video';
      content_icon := '📹';
    ELSE
      content_type_text := 'E-Book';
      content_icon := '📚';
    END IF;

    -- Create notification message and metadata
    notification_message := content_icon || ' ' || content_type_text || ' Baharu!' || E'\n' ||
      '"' || NEW.title || '" oleh ' || COALESCE(NEW.author, 'Penulis') || ' telah ditambah.';

    notification_metadata := jsonb_build_object(
      'title', content_icon || ' ' || content_type_text || ' Baharu!',
      'body', '"' || NEW.title || '" oleh ' || COALESCE(NEW.author, 'Penulis') || ' telah ditambah.',
      'type', 'content_published',
      'icon', content_icon,
      'action_url', CASE WHEN TG_TABLE_NAME = 'video_kitab' THEN '/kitab' ELSE '/ebook' END,
      'data', jsonb_build_object(
        'content_type', TG_TABLE_NAME,
        'title', NEW.title,
        'author', COALESCE(NEW.author, 'Penulis')
      ),
      'created_at', NOW()::text
    );

    -- Insert notification for all active subscribers
    INSERT INTO user_notifications (
      user_id,
      message,
      metadata,
      status,
      delivery_status,
      delivered_at
    )
    SELECT
      id,
      notification_message,
      notification_metadata,
      'unread',
      'delivered',
      NOW()
    FROM profiles
    WHERE role = 'student'
    AND subscription_status = 'active';

    GET DIAGNOSTICS notification_count = ROW_COUNT;

    RAISE NOTICE 'Content published notification sent to % users', notification_count;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Content notification failed: %', SQLERRM;
  RETURN NEW;
END;
$trigger_direct$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create triggers for direct notifications
DROP TRIGGER IF EXISTS content_published_video_kitab_direct ON video_kitab;
CREATE TRIGGER content_published_video_kitab_direct
  AFTER INSERT OR UPDATE ON video_kitab
  FOR EACH ROW
  EXECUTE FUNCTION trigger_content_published_direct();

DROP TRIGGER IF EXISTS content_published_ebooks_direct ON ebooks;
CREATE TRIGGER content_published_ebooks_direct
  AFTER INSERT OR UPDATE ON ebooks
  FOR EACH ROW
  EXECUTE FUNCTION trigger_content_published_direct();

-- 4. Create maintenance notification function
CREATE OR REPLACE FUNCTION send_maintenance_notification_direct(
  scheduled_time TEXT,
  duration_text TEXT,
  maintenance_description TEXT
)
RETURNS jsonb AS $maintenance_direct$
DECLARE
  notification_count INTEGER := 0;
  notification_message TEXT;
  notification_metadata JSONB;
BEGIN
  -- Create message and metadata
  notification_message := '🔧 Penyelenggaraan Sistem' || E'\n' ||
    'Sistem akan diselenggara pada ' || scheduled_time || ' selama ' || duration_text || '. ' || maintenance_description;

  notification_metadata := jsonb_build_object(
    'title', '🔧 Penyelenggaraan Sistem',
    'body', 'Sistem akan diselenggara pada ' || scheduled_time || ' selama ' || duration_text || '. ' || maintenance_description,
    'type', 'system_maintenance',
    'icon', '🔧',
    'action_url', '/notifications',
    'data', jsonb_build_object(
      'scheduled_time', scheduled_time,
      'duration', duration_text,
      'description', maintenance_description
    ),
    'created_at', NOW()::text
  );

  -- Insert notification for all users
  INSERT INTO user_notifications (
    user_id,
    message,
    metadata,
    status,
    delivery_status,
    delivered_at
  )
  SELECT
    id,
    notification_message,
    notification_metadata,
    'unread',
    'delivered',
    NOW()
  FROM profiles;

  GET DIAGNOSTICS notification_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'success', true,
    'notifications_sent', notification_count,
    'message', 'Maintenance notification sent to ' || notification_count || ' users'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$maintenance_direct$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Grant permissions
GRANT EXECUTE ON FUNCTION send_admin_announcement_direct TO authenticated;
GRANT EXECUTE ON FUNCTION send_maintenance_notification_direct TO authenticated;
GRANT EXECUTE ON FUNCTION trigger_content_published_direct TO authenticated;

-- 6. Test the system
INSERT INTO user_notifications (
  user_id,
  message,
  metadata,
  status,
  delivery_status,
  delivered_at
)
SELECT
  id,
  '🎉 Sistema Notification Siap!' || E'\n' || 'Notification system telah disetup dan siap untuk digunakan.',
  jsonb_build_object(
    'title', '🎉 Sistema Notification Siap!',
    'body', 'Notification system telah disetup dan siap untuk digunakan.',
    'type', 'system_announcement',
    'icon', '🎉',
    'action_url', '/notifications',
    'data', jsonb_build_object('setup_complete', true),
    'created_at', NOW()::text
  ),
  'unread',
  'delivered',
  NOW()
FROM profiles
WHERE role = 'student'
LIMIT 1;

-- 7. Show status
SELECT
  'Notification system setup completed successfully!' as status,
  'Functions: send_admin_announcement_direct, send_maintenance_notification_direct, trigger_content_published_direct' as functions_created,
  'Triggers: content_published_video_kitab_direct, content_published_ebooks_direct' as triggers_created,
  'Note: This version works without HTTP extensions - notifications are inserted directly to user_notifications table' as note;