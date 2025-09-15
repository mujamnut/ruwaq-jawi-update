-- Create notification triggers for automated notifications
-- Execute with: supabase db reset OR run migration file

-- Function to trigger notification when new content is published
CREATE OR REPLACE FUNCTION trigger_content_published_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Only trigger for newly activated content (status changed to active)
  IF TG_OP = 'UPDATE' AND OLD.is_active = false AND NEW.is_active = true THEN
    -- Call notification-triggers edge function
    PERFORM
      net.http_post(
        url := current_setting('app.supabase_url') || '/functions/v1/notification-triggers',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
          'apikey', current_setting('app.service_role_key')
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
            'author', NEW.author,
            'category', (
              SELECT name FROM categories
              WHERE id = NEW.category_id
            )
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
        url := current_setting('app.supabase_url') || '/functions/v1/notification-triggers',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
          'apikey', current_setting('app.service_role_key')
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
            'author', NEW.author,
            'category', (
              SELECT name FROM categories
              WHERE id = NEW.category_id
            )
          ),
          'target_roles', ARRAY['student'],
          'target_subscription', ARRAY['active']
        )
      );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers for video_kitab table
DROP TRIGGER IF EXISTS content_published_video_kitab ON video_kitab;
CREATE TRIGGER content_published_video_kitab
  AFTER INSERT OR UPDATE ON video_kitab
  FOR EACH ROW
  EXECUTE FUNCTION trigger_content_published_notification();

-- Create triggers for ebooks table
DROP TRIGGER IF EXISTS content_published_ebooks ON ebooks;
CREATE TRIGGER content_published_ebooks
  AFTER INSERT OR UPDATE ON ebooks
  FOR EACH ROW
  EXECUTE FUNCTION trigger_content_published_notification();

-- Function to check for expiring subscriptions (to be called by cron)
CREATE OR REPLACE FUNCTION check_expiring_subscriptions()
RETURNS void AS $$
DECLARE
  expiring_user RECORD;
  days_warning INTEGER[] := ARRAY[7, 3, 1]; -- Warn at 7, 3, and 1 day before expiry
  warning_day INTEGER;
BEGIN
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
      JOIN subscription_plans sp ON us.plan_id = sp.id
      WHERE us.status = 'active'
        AND us.end_date::date = (CURRENT_DATE + warning_day)
    LOOP
      -- Trigger expiring subscription notification
      PERFORM
        net.http_post(
          url := current_setting('app.supabase_url') || '/functions/v1/notification-triggers',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
            'apikey', current_setting('app.service_role_key')
          ),
          body := jsonb_build_object(
            'type', 'subscription_expiring',
            'data', jsonb_build_object(
              'days_remaining', warning_day,
              'plan_name', expiring_user.plan_name,
              'user_name', expiring_user.full_name
            ),
            'target_users', ARRAY[expiring_user.user_id]
          )
        );
    END LOOP;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function for admin announcements (to be called manually or via API)
CREATE OR REPLACE FUNCTION send_admin_announcement(
  announcement_title TEXT,
  announcement_message TEXT,
  announcement_priority TEXT DEFAULT 'medium',
  target_user_roles TEXT[] DEFAULT ARRAY['student'],
  target_subscription_status TEXT[] DEFAULT ARRAY['active', 'inactive']
)
RETURNS jsonb AS $$
BEGIN
  -- Trigger admin announcement notification
  PERFORM
    net.http_post(
      url := current_setting('app.supabase_url') || '/functions/v1/notification-triggers',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
        'apikey', current_setting('app.service_role_key')
      ),
      body := jsonb_build_object(
        'type', 'admin_announcement',
        'data', jsonb_build_object(
          'title', announcement_title,
          'message', announcement_message,
          'priority', announcement_priority
        ),
        'target_roles', target_user_roles,
        'target_subscription', target_subscription_status
      )
    );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Announcement sent successfully'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function for system maintenance notifications
CREATE OR REPLACE FUNCTION send_maintenance_notification(
  scheduled_time TEXT,
  duration_text TEXT,
  maintenance_description TEXT
)
RETURNS jsonb AS $$
BEGIN
  -- Trigger system maintenance notification
  PERFORM
    net.http_post(
      url := current_setting('app.supabase_url') || '/functions/v1/notification-triggers',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
        'apikey', current_setting('app.service_role_key')
      ),
      body := jsonb_build_object(
        'type', 'system_maintenance',
        'data', jsonb_build_object(
          'scheduled_time', scheduled_time,
          'duration', duration_text,
          'description', maintenance_description
        ),
        'target_roles', ARRAY['student', 'admin']
      )
    );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Maintenance notification sent successfully'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Set configuration for edge function URL (you need to set this in your environment)
-- This should be set in your Supabase dashboard or environment variables
-- ALTER DATABASE postgres SET app.supabase_url = 'https://your-project.supabase.co';
-- ALTER DATABASE postgres SET app.service_role_key = 'your-service-role-key';

COMMENT ON FUNCTION trigger_content_published_notification() IS 'Automatically triggers notifications when new content is published';
COMMENT ON FUNCTION check_expiring_subscriptions() IS 'Checks for expiring subscriptions and sends notifications. Should be called by cron job daily.';
COMMENT ON FUNCTION send_admin_announcement(TEXT, TEXT, TEXT, TEXT[], TEXT[]) IS 'Sends admin announcements to specified user groups';
COMMENT ON FUNCTION send_maintenance_notification(TEXT, TEXT, TEXT) IS 'Sends system maintenance notifications to all users';