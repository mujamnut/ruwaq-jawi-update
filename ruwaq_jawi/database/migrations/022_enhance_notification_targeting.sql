-- Enhance notification targeting system for flexible user targeting
-- This migration adds more flexible targeting options for notifications

-- Add target_criteria column to user_notifications for more specific targeting
ALTER TABLE user_notifications ADD COLUMN IF NOT EXISTS
target_criteria JSONB DEFAULT '{}';

-- Add last_seen_at column to profiles for better inactive user tracking (optional)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS
last_seen_at TIMESTAMP WITH TIME ZONE;

-- Add indexes for better performance on new targeting
CREATE INDEX IF NOT EXISTS idx_user_notifications_target_criteria
ON user_notifications USING GIN (target_criteria);

-- Add purchase_id column for tracking purchase-specific notifications
ALTER TABLE user_notifications ADD COLUMN IF NOT EXISTS
purchase_id UUID REFERENCES payments(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_user_notifications_purchase_id
ON user_notifications(purchase_id);

-- Add index for last_seen_at for better performance
CREATE INDEX IF NOT EXISTS idx_profiles_last_seen_at
ON profiles(last_seen_at);

-- Create function for purchase notification triggers
CREATE OR REPLACE FUNCTION trigger_purchase_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Only trigger for successful payments (payments table uses 'completed' status)
  IF TG_OP = 'UPDATE' AND OLD.status != 'completed' AND NEW.status = 'completed' THEN
    -- Call notification-triggers edge function for payment success
    PERFORM
      net.http_post(
        url := current_setting('app.supabase_url', true) || '/functions/v1/notification-triggers',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.service_role_key', true),
          'apikey', current_setting('app.service_role_key', true)
        ),
        body := jsonb_build_object(
          'type', 'payment_success',
          'data', jsonb_build_object(
            'user_id', NEW.user_id,
            'payment_id', NEW.payment_id,
            'amount', NEW.amount,
            'payment_method', NEW.payment_method,
            'reference_number', NEW.reference_number
          ),
          'target_users', ARRAY[NEW.user_id::text],
          'purchase_id', NEW.id
        )
      );
  END IF;

  -- For new successful payments (INSERT)
  IF TG_OP = 'INSERT' AND NEW.status = 'completed' THEN
    PERFORM
      net.http_post(
        url := current_setting('app.supabase_url', true) || '/functions/v1/notification-triggers',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.service_role_key', true),
          'apikey', current_setting('app.service_role_key', true)
        ),
        body := jsonb_build_object(
          'type', 'payment_success',
          'data', jsonb_build_object(
            'user_id', NEW.user_id,
            'payment_id', NEW.payment_id,
            'amount', NEW.amount,
            'payment_method', NEW.payment_method,
            'reference_number', NEW.reference_number
          ),
          'target_users', ARRAY[NEW.user_id::text],
          'purchase_id', NEW.id
        )
      );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log error but don't fail the main operation
  RAISE WARNING 'Purchase notification trigger failed: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for purchase notifications on payments table
DROP TRIGGER IF EXISTS purchase_notification_trigger ON payments;
CREATE TRIGGER purchase_notification_trigger
  AFTER INSERT OR UPDATE ON payments
  FOR EACH ROW
  EXECUTE FUNCTION trigger_purchase_notification();

-- Update existing content published trigger function to handle video_episodes
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
              WHEN TG_TABLE_NAME = 'video_episodes' THEN 'video_episode'
              WHEN TG_TABLE_NAME = 'ebooks' THEN 'ebook'
              ELSE 'unknown'
            END,
            'title', NEW.title,
            'author', COALESCE(NEW.author, 'Penulis'),
            'category', COALESCE((
              SELECT name FROM categories
              WHERE id = CASE
                WHEN TG_TABLE_NAME = 'video_episodes' THEN (
                  SELECT vk.category_id FROM video_kitab vk
                  WHERE vk.id = NEW.video_kitab_id
                )
                ELSE NEW.category_id
              END
            ), 'Kategori Umum'),
            'parent_kitab', CASE
              WHEN TG_TABLE_NAME = 'video_episodes' THEN (
                SELECT vk.title FROM video_kitab vk
                WHERE vk.id = NEW.video_kitab_id
              )
              ELSE NULL
            END,
            'episode_number', CASE
              WHEN TG_TABLE_NAME = 'video_episodes' THEN NEW.part_number
              ELSE NULL
            END
          ),
          'target_roles', ARRAY['student']
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
              WHEN TG_TABLE_NAME = 'video_episodes' THEN 'video_episode'
              WHEN TG_TABLE_NAME = 'ebooks' THEN 'ebook'
              ELSE 'unknown'
            END,
            'title', NEW.title,
            'author', COALESCE(NEW.author, 'Penulis'),
            'category', COALESCE((
              SELECT name FROM categories
              WHERE id = CASE
                WHEN TG_TABLE_NAME = 'video_episodes' THEN (
                  SELECT vk.category_id FROM video_kitab vk
                  WHERE vk.id = NEW.video_kitab_id
                )
                ELSE NEW.category_id
              END
            ), 'Kategori Umum'),
            'parent_kitab', CASE
              WHEN TG_TABLE_NAME = 'video_episodes' THEN (
                SELECT vk.title FROM video_kitab vk
                WHERE vk.id = NEW.video_kitab_id
              )
              ELSE NULL
            END,
            'episode_number', CASE
              WHEN TG_TABLE_NAME = 'video_episodes' THEN NEW.part_number
              ELSE NULL
            END
          ),
          'target_roles', ARRAY['student']
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

-- Add trigger for video episodes
DROP TRIGGER IF EXISTS content_published_video_episodes ON video_episodes;
CREATE TRIGGER content_published_video_episodes
  AFTER INSERT OR UPDATE ON video_episodes
  FOR EACH ROW
  EXECUTE FUNCTION trigger_content_published_notification();

-- Create function for subscription expiry warnings
CREATE OR REPLACE FUNCTION trigger_subscription_expiry_check()
RETURNS void AS $$
DECLARE
  expiring_user RECORD;
BEGIN
  -- Find users whose subscription expires in 3 days
  FOR expiring_user IN
    SELECT
      us.user_id,
      us.end_date as subscription_end_date,
      sp.name as plan_name,
      p.full_name
    FROM user_subscriptions us
    JOIN subscription_plans sp ON us.subscription_plan_id = sp.id
    JOIN profiles p ON us.user_id = p.id
    WHERE us.status = 'active'
    AND us.end_date <= (CURRENT_DATE + INTERVAL '3 days')
    AND us.end_date > CURRENT_DATE
    -- Only notify once per day
    AND NOT EXISTS (
      SELECT 1 FROM user_notifications un
      WHERE un.user_id = us.user_id
      AND un.metadata->>'type' = 'subscription_expiring'
      AND un.delivered_at::date = CURRENT_DATE
    )
  LOOP
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
          'type', 'subscription_expiring',
          'data', jsonb_build_object(
            'days_remaining', (expiring_user.subscription_end_date - CURRENT_DATE),
            'plan_name', expiring_user.plan_name,
            'expiry_date', expiring_user.subscription_end_date,
            'user_name', expiring_user.full_name
          ),
          'target_users', ARRAY[expiring_user.user_id::text]
        )
      );
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function for inactive user re-engagement
CREATE OR REPLACE FUNCTION trigger_inactive_user_notification()
RETURNS void AS $$
DECLARE
  inactive_user RECORD;
BEGIN
  -- Find users who haven't been active for 7 days and have active subscription
  -- Using last_seen_at if available, otherwise fall back to updated_at
  FOR inactive_user IN
    SELECT
      p.id as user_id,
      p.full_name,
      p.updated_at,
      p.last_seen_at,
      COALESCE(
        p.last_seen_at,
        GREATEST(p.updated_at, us.updated_at)
      ) as last_activity
    FROM profiles p
    JOIN user_subscriptions us ON us.user_id = p.id
    WHERE p.role = 'student'
    AND us.status = 'active'
    AND us.end_date > NOW()
    AND COALESCE(
      p.last_seen_at,
      GREATEST(p.updated_at, us.updated_at)
    ) < (NOW() - INTERVAL '7 days')
    -- Only notify once per week
    AND NOT EXISTS (
      SELECT 1 FROM user_notifications un
      WHERE un.user_id = p.id
      AND un.metadata->>'type' = 'inactive_user_engagement'
      AND un.delivered_at > (NOW() - INTERVAL '7 days')
    )
  LOOP
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
          'type', 'inactive_user_engagement',
          'data', jsonb_build_object(
            'user_name', inactive_user.full_name,
            'days_inactive', EXTRACT(DAY FROM (NOW() - inactive_user.last_activity))::text,
            'last_activity', inactive_user.last_activity
          ),
          'target_users', ARRAY[inactive_user.user_id::text]
        )
      );
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update user_notifications table comments
COMMENT ON COLUMN user_notifications.target_criteria IS 'JSON criteria for flexible targeting (e.g., purchase_specific, role_based, etc.)';
COMMENT ON COLUMN user_notifications.purchase_id IS 'Reference to specific purchase that triggered this notification';
COMMENT ON FUNCTION trigger_purchase_notification() IS 'Triggers notifications when users make successful payments';
COMMENT ON FUNCTION trigger_subscription_expiry_check() IS 'Checks for expiring subscriptions and sends warnings';
COMMENT ON FUNCTION trigger_inactive_user_notification() IS 'Re-engages inactive users with targeted notifications';

-- Create function to update user last seen timestamp
CREATE OR REPLACE FUNCTION update_user_last_seen(user_uuid UUID)
RETURNS void AS $$
BEGIN
  UPDATE profiles
  SET last_seen_at = NOW(),
      updated_at = NOW()
  WHERE id = user_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION update_user_last_seen(UUID) IS 'Updates user last_seen_at timestamp for activity tracking';

-- Grant execution to authenticated users so they can update their own last_seen_at
GRANT EXECUTE ON FUNCTION update_user_last_seen(UUID) TO authenticated;

-- Add sample target_criteria examples for documentation
-- This would be used when inserting notifications with specific targeting:
-- target_criteria examples:
-- {'purchase_specific': true, 'payment_id': 'payment_id'}
-- {'role_based': true, 'roles': ['student'], 'subscription_status': ['active']}
-- {'content_specific': true, 'content_type': 'video_kitab', 'category_id': 'uuid'}
-- {'admin_announcement': true, 'priority': 'high', 'target_all_users': true}
-- {'re_engagement': true, 'inactive_days': 7, 'subscription_status': ['active']}