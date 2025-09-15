-- Direct Notification System - Guna table user_notifications sahaja
-- No need to drop existing functions, just create new ones with different names
-- Run this in Supabase SQL Editor

-- 1. Create simple notification insert function (core function)
CREATE OR REPLACE FUNCTION insert_notification(
  target_user_ids UUID[],
  notification_title TEXT,
  notification_body TEXT,
  notification_type TEXT DEFAULT 'general',
  notification_icon TEXT DEFAULT 'ℹ️',
  action_url TEXT DEFAULT '/notifications',
  extra_data JSONB DEFAULT '{}'
)
RETURNS jsonb AS $insert_notif$
DECLARE
  notification_count INTEGER := 0;
  notification_message TEXT;
  notification_metadata JSONB;
  user_id UUID;
BEGIN
  -- Validate inputs
  IF target_user_ids IS NULL OR array_length(target_user_ids, 1) IS NULL OR array_length(target_user_ids, 1) = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'No target users provided'
    );
  END IF;

  IF notification_title IS NULL OR trim(notification_title) = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Notification title cannot be empty'
    );
  END IF;

  -- Create message and metadata
  notification_message := notification_title || E'\n' || COALESCE(notification_body, '');
  notification_metadata := jsonb_build_object(
    'title', notification_title,
    'body', notification_body,
    'type', notification_type,
    'icon', notification_icon,
    'action_url', action_url,
    'data', extra_data,
    'created_at', NOW()::text
  );

  -- Insert notification for each target user
  FOREACH user_id IN ARRAY target_user_ids
  LOOP
    INSERT INTO user_notifications (
      user_id,
      message,
      metadata,
      status,
      delivery_status,
      delivered_at
    ) VALUES (
      user_id,
      notification_message,
      notification_metadata,
      'unread',
      'delivered',
      NOW()
    );

    notification_count := notification_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'notifications_sent', notification_count,
    'message', 'Sent ' || notification_count || ' notifications'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$insert_notif$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Admin announcement wrapper function
CREATE OR REPLACE FUNCTION send_admin_announcement_simple(
  announcement_title TEXT,
  announcement_message TEXT,
  announcement_priority TEXT DEFAULT 'medium'
)
RETURNS jsonb AS $admin_simple$
DECLARE
  student_ids UUID[];
  icon_text TEXT;
BEGIN
  -- Get all student IDs
  SELECT COALESCE(array_agg(id), ARRAY[]::UUID[]) INTO student_ids
  FROM profiles
  WHERE role = 'student';

  -- Check if any students found
  IF array_length(student_ids, 1) IS NULL OR array_length(student_ids, 1) = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'No students found to send announcement to'
    );
  END IF;

  -- Set icon based on priority
  icon_text := CASE
    WHEN announcement_priority = 'high' THEN '🚨'
    WHEN announcement_priority = 'medium' THEN '📢'
    ELSE 'ℹ️'
  END;

  -- Use core function to send notifications
  RETURN insert_notification(
    student_ids,
    icon_text || ' ' || announcement_title,
    announcement_message,
    'admin_announcement',
    icon_text,
    '/notifications',
    jsonb_build_object('priority', announcement_priority, 'admin_message', true)
  );
END;
$admin_simple$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Content published notification trigger (simple version)
CREATE OR REPLACE FUNCTION notify_content_published()
RETURNS TRIGGER AS $content_trigger$
DECLARE
  active_student_ids UUID[];
  content_type_text TEXT;
  content_icon TEXT;
  category_name TEXT;
  notification_title TEXT;
  notification_body TEXT;
BEGIN
  -- Only trigger for newly activated content
  IF (TG_OP = 'UPDATE' AND OLD.is_active = false AND NEW.is_active = true) OR
     (TG_OP = 'INSERT' AND NEW.is_active = true) THEN

    -- Get active student IDs
    SELECT COALESCE(array_agg(id), ARRAY[]::UUID[]) INTO active_student_ids
    FROM profiles
    WHERE role = 'student'
    AND subscription_status = 'active';

    -- Skip if no active students
    IF array_length(active_student_ids, 1) IS NULL OR array_length(active_student_ids, 1) = 0 THEN
      RETURN NEW;
    END IF;

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

    -- Create notification content
    notification_title := content_icon || ' ' || content_type_text || ' Baharu!';
    notification_body := '"' || NEW.title || '" oleh ' || COALESCE(NEW.author, 'Penulis') || ' telah ditambah dalam kategori ' || category_name || '.';

    -- Send notifications
    PERFORM insert_notification(
      active_student_ids,
      notification_title,
      notification_body,
      'content_published',
      content_icon,
      CASE WHEN TG_TABLE_NAME = 'video_kitab' THEN '/kitab' ELSE '/ebook' END,
      jsonb_build_object(
        'content_type', TG_TABLE_NAME,
        'title', NEW.title,
        'author', COALESCE(NEW.author, 'Penulis'),
        'category', category_name
      )
    );

    RAISE NOTICE 'Content published notification sent for: %', NEW.title;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Content notification failed: %', SQLERRM;
  RETURN NEW;
END;
$content_trigger$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Maintenance notification function
CREATE OR REPLACE FUNCTION send_maintenance_alert(
  scheduled_time TEXT,
  duration_text TEXT,
  maintenance_description TEXT
)
RETURNS jsonb AS $maintenance_alert$
DECLARE
  all_user_ids UUID[];
BEGIN
  -- Get all user IDs
  SELECT COALESCE(array_agg(id), ARRAY[]::UUID[]) INTO all_user_ids
  FROM profiles;

  -- Send maintenance notification to all users
  RETURN insert_notification(
    all_user_ids,
    '🔧 Penyelenggaraan Sistem',
    'Sistem akan diselenggara pada ' || scheduled_time || ' selama ' || duration_text || '. ' || maintenance_description,
    'system_maintenance',
    '🔧',
    '/notifications',
    jsonb_build_object(
      'scheduled_time', scheduled_time,
      'duration', duration_text,
      'description', maintenance_description
    )
  );
END;
$maintenance_alert$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Create triggers (with unique names to avoid conflicts)
DROP TRIGGER IF EXISTS notify_video_kitab_published ON video_kitab;
CREATE TRIGGER notify_video_kitab_published
  AFTER INSERT OR UPDATE ON video_kitab
  FOR EACH ROW
  EXECUTE FUNCTION notify_content_published();

DROP TRIGGER IF EXISTS notify_ebook_published ON ebooks;
CREATE TRIGGER notify_ebook_published
  AFTER INSERT OR UPDATE ON ebooks
  FOR EACH ROW
  EXECUTE FUNCTION notify_content_published();

-- 6. Grant permissions
GRANT EXECUTE ON FUNCTION insert_notification TO authenticated;
GRANT EXECUTE ON FUNCTION send_admin_announcement_simple TO authenticated;
GRANT EXECUTE ON FUNCTION send_maintenance_alert TO authenticated;
GRANT EXECUTE ON FUNCTION notify_content_published TO authenticated;

-- 7. Test dengan create notification terus
SELECT insert_notification(
  ARRAY(SELECT id FROM profiles WHERE role = 'student' LIMIT 1),
  '🎉 Sistema Notification Siap!',
  'Notification system telah disetup dengan jayanya. Anda akan menerima notifikasi untuk content baru, pengumuman admin, dan maintenance sistem.',
  'system_announcement',
  '🎉',
  '/notifications',
  '{"setup_complete": true}'::jsonb
) as setup_test;

-- 8. Test admin announcement
SELECT send_admin_announcement_simple(
  'Sistem Notification Aktif',
  'Notification system kini aktif dan berfungsi. Anda akan menerima pemberitahuan penting melalui sistem ini.',
  'medium'
) as admin_test;

-- 9. Show final status
SELECT
  'Direct notification system ready!' as status,
  'Core function: insert_notification' as core_function,
  'Helper functions: send_admin_announcement_simple, send_maintenance_alert' as helper_functions,
  'Triggers: notify_video_kitab_published, notify_ebook_published' as triggers_created,
  'Implementation: Direct insert to user_notifications table' as implementation,
  'No dependencies on external functions' as note;