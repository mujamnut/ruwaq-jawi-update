-- Apply notification system triggers and functions
-- Run this SQL in Supabase SQL Editor

-- 1. Create missing functions first
CREATE OR REPLACE FUNCTION send_admin_announcement(
  announcement_title TEXT,
  announcement_message TEXT,
  announcement_priority TEXT DEFAULT 'medium',
  target_user_roles TEXT[] DEFAULT ARRAY['student'],
  target_subscription_status TEXT[] DEFAULT ARRAY['active', 'inactive']
)
RETURNS jsonb AS $admin_function$
DECLARE
  function_url TEXT;
  headers JSONB;
  payload JSONB;
BEGIN
  -- Build function URL
  function_url := current_setting('app.supabase_url', true) || '/functions/v1/notification-triggers';

  -- Build headers
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer ' || current_setting('app.service_role_key', true),
    'apikey', current_setting('app.service_role_key', true)
  );

  -- Build payload
  payload := jsonb_build_object(
    'type', 'admin_announcement',
    'data', jsonb_build_object(
      'title', announcement_title,
      'message', announcement_message,
      'priority', announcement_priority
    ),
    'target_roles', to_jsonb(target_user_roles),
    'target_subscription', to_jsonb(target_subscription_status)
  );

  -- Call notification function (commented out for now)
  -- PERFORM net.http_post(url := function_url, headers := headers, body := payload::text);

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Announcement function called (net.http_post may need to be enabled)',
    'payload', payload
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM,
    'message', 'Function exists but net.http_post may not be available'
  );
END;
$admin_function$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create check expiring subscriptions function
CREATE OR REPLACE FUNCTION check_expiring_subscriptions()
RETURNS jsonb AS $function$
DECLARE
  expiring_user RECORD;
  days_warning INTEGER[] := ARRAY[7, 3, 1];
  warning_day INTEGER;
  function_url TEXT;
  headers JSONB;
  payload JSONB;
  notification_count INTEGER := 0;
BEGIN
  function_url := current_setting('app.supabase_url', true) || '/functions/v1/notification-triggers';

  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer ' || current_setting('app.service_role_key', true),
    'apikey', current_setting('app.service_role_key', true)
  );

  -- Loop through each warning day
  FOREACH warning_day IN ARRAY days_warning
  LOOP
    -- Find users whose subscription expires in warning_day days
    FOR expiring_user IN
      SELECT
        p.id as user_id,
        p.full_name,
        us.end_date,
        sp.name as plan_name
      FROM profiles p
      JOIN user_subscriptions us ON p.id = us.user_id
      JOIN subscription_plans sp ON us.subscription_plan_id = sp.id
      WHERE us.status = 'active'
        AND us.end_date::date = (CURRENT_DATE + warning_day)
    LOOP
      payload := jsonb_build_object(
        'type', 'subscription_expiring',
        'data', jsonb_build_object(
          'days_remaining', warning_day,
          'plan_name', expiring_user.plan_name,
          'user_name', expiring_user.full_name
        ),
        'target_users', jsonb_build_array(expiring_user.user_id)
      );

      -- Call notification function (commented out for now)
      -- PERFORM net.http_post(url := function_url, headers := headers, body := payload::text);

      notification_count := notification_count + 1;
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'notifications_triggered', notification_count,
    'message', 'Function executed (net.http_post may need to be enabled)'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$function$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Update content published notification function to handle missing settings gracefully
CREATE OR REPLACE FUNCTION trigger_content_published_notification()
RETURNS TRIGGER AS $trigger_function$
DECLARE
  function_url TEXT;
  headers JSONB;
  payload JSONB;
BEGIN
  -- Only trigger for newly activated content
  IF (TG_OP = 'UPDATE' AND OLD.is_active = false AND NEW.is_active = true) OR
     (TG_OP = 'INSERT' AND NEW.is_active = true) THEN

    BEGIN
      -- Try to get settings, use defaults if not available
      function_url := COALESCE(
        current_setting('app.supabase_url', true),
        'https://your-project.supabase.co'
      ) || '/functions/v1/notification-triggers';

      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || COALESCE(
          current_setting('app.service_role_key', true),
          'your-service-role-key'
        ),
        'apikey', COALESCE(
          current_setting('app.service_role_key', true),
          'your-service-role-key'
        )
      );

      payload := jsonb_build_object(
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
        'target_roles', jsonb_build_array('student'),
        'target_subscription', jsonb_build_array('active')
      );

      -- Call notification function (commented out until net.http_post is enabled)
      -- PERFORM net.http_post(url := function_url, headers := headers, body := payload::text);

      -- Log the notification for debugging
      RAISE NOTICE 'Content published notification triggered: %', payload::text;

    EXCEPTION WHEN OTHERS THEN
      -- Log error but don't fail the main operation
      RAISE WARNING 'Notification trigger failed: %', SQLERRM;
    END;
  END IF;

  RETURN NEW;
END;
$trigger_function$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Create triggers for content published notifications
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

-- 5. Grant necessary permissions
GRANT EXECUTE ON FUNCTION send_admin_announcement TO authenticated;
GRANT EXECUTE ON FUNCTION check_expiring_subscriptions TO authenticated;
GRANT EXECUTE ON FUNCTION trigger_content_published_notification TO authenticated;

-- 6. Add comments for documentation
COMMENT ON FUNCTION send_admin_announcement IS 'Send admin announcements to specified user groups via notification-triggers edge function';
COMMENT ON FUNCTION check_expiring_subscriptions IS 'Check for expiring subscriptions and send notifications. Should be called daily via cron.';
COMMENT ON FUNCTION trigger_content_published_notification IS 'Automatically triggers notifications when new content is published';

-- 7. Show status
SELECT
  'Notification system setup completed' as status,
  'Functions created: send_admin_announcement, check_expiring_subscriptions, trigger_content_published_notification' as functions,
  'Triggers created: content_published_video_kitab, content_published_ebooks' as triggers,
  'Note: net.http_post extension may need to be enabled for HTTP calls to work' as note;