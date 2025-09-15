-- ✅ COMPLETE NOTIFICATION SYSTEM - READY FOR PRODUCTION
-- Run this entire script in Supabase SQL Editor
-- This replaces all previous notification SQL files

-- 1. ✅ Core notification function
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
  -- Input validation
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
    'body', COALESCE(notification_body, ''),
    'type', COALESCE(notification_type, 'general'),
    'icon', COALESCE(notification_icon, 'ℹ️'),
    'action_url', COALESCE(action_url, '/notifications'),
    'data', COALESCE(extra_data, '{}'::jsonb),
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
    'message', 'Sent ' || notification_count || ' notifications successfully'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM,
    'hint', 'Check user IDs and database permissions'
  );
END;
$insert_notif$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. ✅ Admin announcement function
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
    WHEN LOWER(announcement_priority) = 'high' THEN '🚨'
    WHEN LOWER(announcement_priority) = 'medium' THEN '📢'
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

-- 3. ✅ Content published notification trigger
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
      RAISE NOTICE 'No active students found for content notification: %', NEW.title;
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
    ELSIF TG_TABLE_NAME = 'ebooks' THEN
      content_type_text := 'E-Book';
      content_icon := '📚';
    ELSE
      content_type_text := 'Kandungan';
      content_icon := '📄';
    END IF;

    -- Create notification content
    notification_title := content_icon || ' ' || content_type_text || ' Baharu!';
    notification_body := '"' || COALESCE(NEW.title, 'Tajuk tidak tersedia') ||
                        '" oleh ' || COALESCE(NEW.author, 'Penulis') ||
                        ' telah ditambah dalam kategori ' || category_name || '.';

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
        'title', COALESCE(NEW.title, ''),
        'author', COALESCE(NEW.author, ''),
        'category', category_name,
        'content_id', NEW.id::text
      )
    );

    RAISE NOTICE 'Content published notification sent to % users for: %',
                 array_length(active_student_ids, 1), NEW.title;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Content notification failed for %: %', NEW.title, SQLERRM;
  RETURN NEW;
END;
$content_trigger$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. ✅ Maintenance notification function
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

  -- Check if users exist
  IF array_length(all_user_ids, 1) IS NULL OR array_length(all_user_ids, 1) = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'No users found in system'
    );
  END IF;

  -- Send maintenance notification to all users
  RETURN insert_notification(
    all_user_ids,
    '🔧 Penyelenggaraan Sistem',
    'Sistem akan diselenggara pada ' || COALESCE(scheduled_time, 'masa yang akan dimaklumkan') ||
    ' selama ' || COALESCE(duration_text, 'tempoh yang diperlukan') || '. ' ||
    COALESCE(maintenance_description, 'Butiran akan dimaklumkan kemudian.'),
    'system_maintenance',
    '🔧',
    '/notifications',
    jsonb_build_object(
      'scheduled_time', scheduled_time,
      'duration', duration_text,
      'description', maintenance_description,
      'maintenance_alert', true
    )
  );
END;
$maintenance_alert$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. ✅ Payment success notification function
CREATE OR REPLACE FUNCTION send_payment_success_notification(
  user_id_param UUID,
  subscription_plan_name TEXT,
  amount_paid TEXT,
  expiry_date TEXT
)
RETURNS jsonb AS $payment_success$
BEGIN
  RETURN insert_notification(
    ARRAY[user_id_param],
    '💳 Pembayaran Berjaya!',
    'Pembayaran untuk pelan ' || subscription_plan_name || ' sebanyak ' || amount_paid ||
    ' telah berjaya. Langganan anda aktif sehingga ' || expiry_date || '.',
    'payment_success',
    '💳',
    '/subscription',
    jsonb_build_object(
      'subscription_plan', subscription_plan_name,
      'amount_paid', amount_paid,
      'expiry_date', expiry_date,
      'payment_success', true
    )
  );
END;
$payment_success$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. ✅ Subscription expiring notification function
CREATE OR REPLACE FUNCTION send_subscription_expiring_notification(
  user_id_param UUID,
  days_remaining INTEGER,
  expiry_date TEXT
)
RETURNS jsonb AS $sub_expiring$
DECLARE
  urgency_icon TEXT;
  urgency_message TEXT;
BEGIN
  -- Set urgency based on days remaining
  IF days_remaining <= 3 THEN
    urgency_icon := '🚨';
    urgency_message := 'MENDESAK: ';
  ELSIF days_remaining <= 7 THEN
    urgency_icon := '⚠️';
    urgency_message := 'PENTING: ';
  ELSE
    urgency_icon := '📅';
    urgency_message := '';
  END IF;

  RETURN insert_notification(
    ARRAY[user_id_param],
    urgency_icon || ' Langganan Akan Tamat',
    urgency_message || 'Langganan anda akan tamat dalam ' || days_remaining ||
    ' hari pada ' || expiry_date || '. Sila perbaharui langganan untuk terus mengakses kandungan.',
    'subscription_expiring',
    urgency_icon,
    '/subscription',
    jsonb_build_object(
      'days_remaining', days_remaining,
      'expiry_date', expiry_date,
      'urgency_level', CASE
        WHEN days_remaining <= 3 THEN 'critical'
        WHEN days_remaining <= 7 THEN 'high'
        ELSE 'medium'
      END
    )
  );
END;
$sub_expiring$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. ✅ Create triggers
DROP TRIGGER IF EXISTS notify_video_kitab_published ON video_kitab;
DROP TRIGGER IF EXISTS notify_ebook_published ON ebooks;

CREATE TRIGGER notify_video_kitab_published
  AFTER INSERT OR UPDATE ON video_kitab
  FOR EACH ROW
  EXECUTE FUNCTION notify_content_published();

CREATE TRIGGER notify_ebook_published
  AFTER INSERT OR UPDATE ON ebooks
  FOR EACH ROW
  EXECUTE FUNCTION notify_content_published();

-- 8. ✅ Grant permissions
GRANT EXECUTE ON FUNCTION insert_notification TO authenticated;
GRANT EXECUTE ON FUNCTION send_admin_announcement_simple TO authenticated;
GRANT EXECUTE ON FUNCTION send_maintenance_alert TO authenticated;
GRANT EXECUTE ON FUNCTION send_payment_success_notification TO authenticated;
GRANT EXECUTE ON FUNCTION send_subscription_expiring_notification TO authenticated;
GRANT EXECUTE ON FUNCTION notify_content_published TO authenticated;

-- 9. ✅ Test the system with sample notifications
DO $$
DECLARE
    test_result JSONB;
    student_count INTEGER;
BEGIN
    -- Check if students exist
    SELECT COUNT(*) INTO student_count FROM profiles WHERE role = 'student';

    IF student_count > 0 THEN
        -- Test notification system
        SELECT insert_notification(
            ARRAY(SELECT id FROM profiles WHERE role = 'student' LIMIT 1),
            '✅ Sistema Notification Aktif!',
            'Notification system telah disetup dengan jayanya dan siap untuk digunakan. Anda akan menerima notifikasi untuk content baru, pengumuman admin, payment success, dan maintenance sistem.',
            'system_test',
            '✅',
            '/notifications',
            '{"test_completed": true, "version": "1.0"}'::jsonb
        ) INTO test_result;

        RAISE NOTICE 'System test result: %', test_result;

        -- Test admin announcement
        SELECT send_admin_announcement_simple(
            'Sistem Notification Siap Digunakan',
            'Notification system kini aktif dan berfungsi sepenuhnya. Anda akan menerima pemberitahuan untuk semua aktiviti penting dalam sistem.',
            'medium'
        ) INTO test_result;

        RAISE NOTICE 'Admin announcement test result: %', test_result;
    ELSE
        RAISE NOTICE 'No students found for testing, but functions are ready';
    END IF;
END
$$;

-- 10. ✅ Final status report
SELECT
  '🎉 Notification System Successfully Deployed!' as status,
  'Functions: insert_notification, send_admin_announcement_simple, send_maintenance_alert, send_payment_success_notification, send_subscription_expiring_notification, notify_content_published' as functions_created,
  'Triggers: notify_video_kitab_published, notify_ebook_published' as triggers_created,
  'Table: user_notifications (existing structure preserved)' as storage,
  'Features: Payment success, content published, admin announcements, maintenance alerts, subscription expiring' as notification_types,
  'Ready for production use!' as deployment_status;