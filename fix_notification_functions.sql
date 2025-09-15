-- Fix notification system - Drop and recreate functions with correct signatures
-- Run this in Supabase SQL Editor

-- 1. Drop existing functions first
DROP FUNCTION IF EXISTS check_expiring_subscriptions();
DROP FUNCTION IF EXISTS send_admin_announcement(TEXT, TEXT, TEXT, TEXT[], TEXT[]);
DROP FUNCTION IF EXISTS send_maintenance_notification(TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS trigger_content_published_notification();

-- 2. Create admin announcement function (direct insert)
CREATE OR REPLACE FUNCTION send_admin_announcement_direct(
  announcement_title TEXT,
  announcement_message TEXT,
  announcement_priority TEXT DEFAULT 'medium'
)
RETURNS jsonb AS $admin_direct$
DECLARE
  notification_count INTEGER := 0;
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

-- 3. Create content published notification trigger (direct insert)
CREATE OR REPLACE FUNCTION trigger_content_published_direct()
RETURNS TRIGGER AS $trigger_direct$
DECLARE
  notification_count INTEGER := 0;
  notification_message TEXT;
  notification_metadata JSONB;
  content_type_text TEXT;
  content_icon TEXT;
  category_name TEXT;
BEGIN
  -- Only trigger for newly activated content
  IF (TG_OP = 'UPDATE' AND OLD.is_active = false AND NEW.is_active = true) OR
     (TG_OP = 'INSERT' AND NEW.is_active = true) THEN

    -- Get category name
    SELECT name INTO category_name
    FROM categories
    WHERE id = NEW.category_id;

    category_name := COALESCE(category_name, 'Kategori Umum');

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
      '"' || NEW.title || '" oleh ' || COALESCE(NEW.author, 'Penulis') || ' telah ditambah dalam kategori ' || category_name || '.';

    notification_metadata := jsonb_build_object(
      'title', content_icon || ' ' || content_type_text || ' Baharu!',
      'body', '"' || NEW.title || '" oleh ' || COALESCE(NEW.author, 'Penulis') || ' telah ditambah dalam kategori ' || category_name || '.',
      'type', 'content_published',
      'icon', content_icon,
      'action_url', CASE WHEN TG_TABLE_NAME = 'video_kitab' THEN '/kitab' ELSE '/ebook' END,
      'data', jsonb_build_object(
        'content_type', TG_TABLE_NAME,
        'title', NEW.title,
        'author', COALESCE(NEW.author, 'Penulis'),
        'category', category_name
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
      p.id,
      notification_message,
      notification_metadata,
      'unread',
      'delivered',
      NOW()
    FROM profiles p
    WHERE p.role = 'student'
    AND p.subscription_status = 'active';

    GET DIAGNOSTICS notification_count = ROW_COUNT;

    RAISE NOTICE 'Content published notification sent to % users for %', notification_count, NEW.title;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Content notification failed: %', SQLERRM;
  RETURN NEW;
END;
$trigger_direct$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Create maintenance notification function (direct insert)
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

-- 5. Drop existing triggers first, then create new ones
DROP TRIGGER IF EXISTS content_published_video_kitab ON video_kitab;
DROP TRIGGER IF EXISTS content_published_ebooks ON ebooks;
DROP TRIGGER IF EXISTS content_published_video_kitab_direct ON video_kitab;
DROP TRIGGER IF EXISTS content_published_ebooks_direct ON ebooks;

-- Create new triggers
CREATE TRIGGER content_published_video_kitab_direct
  AFTER INSERT OR UPDATE ON video_kitab
  FOR EACH ROW
  EXECUTE FUNCTION trigger_content_published_direct();

CREATE TRIGGER content_published_ebooks_direct
  AFTER INSERT OR UPDATE ON ebooks
  FOR EACH ROW
  EXECUTE FUNCTION trigger_content_published_direct();

-- 6. Grant permissions
GRANT EXECUTE ON FUNCTION send_admin_announcement_direct TO authenticated;
GRANT EXECUTE ON FUNCTION send_maintenance_notification_direct TO authenticated;
GRANT EXECUTE ON FUNCTION trigger_content_published_direct TO authenticated;

-- 7. Test the functions work
SELECT send_admin_announcement_direct(
  'Sistema Notification Aktif!',
  'Notification system telah disetup dan siap untuk digunakan. Anda akan menerima notifikasi untuk content baru, pengumuman admin, dan maintenance.',
  'medium'
) as admin_announcement_test;

-- 8. Show setup status
SELECT
  'Notification system setup completed!' as status,
  'Functions created: send_admin_announcement_direct, send_maintenance_notification_direct, trigger_content_published_direct' as functions_created,
  'Triggers created: content_published_video_kitab_direct, content_published_ebooks_direct' as triggers_created,
  'All functions use direct insert to user_notifications table' as implementation_note;