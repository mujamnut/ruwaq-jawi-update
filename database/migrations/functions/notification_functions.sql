-- Notification System Helper Functions
-- Date: 2025-09-22
-- Purpose: Create helper functions for the new notification system

-- Function: Create a broadcast notification
CREATE OR REPLACE FUNCTION create_broadcast_notification(
  p_title TEXT,
  p_message TEXT,
  p_metadata JSONB DEFAULT '{}'::JSONB,
  p_target_roles TEXT[] DEFAULT ARRAY['student']
) RETURNS UUID AS $$
DECLARE
  notification_id UUID;
BEGIN
  INSERT INTO notifications (
    type,
    title,
    message,
    target_type,
    target_criteria,
    metadata
  ) VALUES (
    'broadcast',
    p_title,
    p_message,
    'all',
    jsonb_build_object('target_roles', p_target_roles),
    p_metadata
  ) RETURNING id INTO notification_id;

  RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Create a personal notification
CREATE OR REPLACE FUNCTION create_personal_notification(
  p_user_id UUID,
  p_title TEXT,
  p_message TEXT,
  p_metadata JSONB DEFAULT '{}'::JSONB
) RETURNS UUID AS $$
DECLARE
  notification_id UUID;
BEGIN
  INSERT INTO notifications (
    type,
    title,
    message,
    target_type,
    target_criteria,
    metadata
  ) VALUES (
    'personal',
    p_title,
    p_message,
    'user',
    jsonb_build_object('user_id', p_user_id),
    p_metadata
  ) RETURNING id INTO notification_id;

  -- Immediately create read record for the target user
  INSERT INTO notification_reads (notification_id, user_id)
  VALUES (notification_id, p_user_id);

  RETURN notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Mark notification as read for a user (lazy insert)
CREATE OR REPLACE FUNCTION mark_notification_read(
  p_notification_id UUID,
  p_user_id UUID
) RETURNS BOOLEAN AS $$
BEGIN
  INSERT INTO notification_reads (notification_id, user_id, is_read, read_at)
  VALUES (p_notification_id, p_user_id, TRUE, NOW())
  ON CONFLICT (notification_id, user_id)
  DO UPDATE SET
    is_read = TRUE,
    read_at = NOW();

  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get notifications for a user (hybrid approach)
CREATE OR REPLACE FUNCTION get_user_notifications(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
) RETURNS TABLE (
  id UUID,
  type TEXT,
  title TEXT,
  message TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ,
  is_read BOOLEAN,
  read_at TIMESTAMPTZ,
  source TEXT
) AS $$
BEGIN
  RETURN QUERY
  WITH new_notifications AS (
    SELECT
      n.id,
      n.type,
      n.title,
      n.message,
      n.metadata,
      n.created_at,
      COALESCE(nr.is_read, FALSE) as is_read,
      nr.read_at,
      'new_system'::TEXT as source
    FROM notifications n
    LEFT JOIN notification_reads nr ON n.id = nr.notification_id AND nr.user_id = p_user_id
    WHERE
      n.is_active = TRUE
      AND n.expires_at > NOW()
      AND (
        n.target_type = 'all'
        OR (n.target_type = 'user' AND (n.target_criteria->>'user_id')::UUID = p_user_id)
        OR (n.target_type = 'role' AND 'student' = ANY(
          SELECT jsonb_array_elements_text(n.target_criteria->'target_roles')
        ))
      )
  ),
  legacy_notifications AS (
    SELECT
      un.id,
      CASE
        WHEN un.user_id IS NULL THEN 'broadcast'
        ELSE 'personal'
      END::TEXT as type,
      (un.metadata->>'title')::TEXT as title,
      un.message,
      un.metadata,
      un.delivered_at as created_at,
      CASE
        WHEN un.user_id IS NULL THEN
          CASE
            WHEN p_user_id::TEXT = ANY(
              SELECT jsonb_array_elements_text(un.metadata->'read_by')
            ) THEN TRUE
            ELSE FALSE
          END
        ELSE TRUE  -- Assume personal notifications in legacy are read
      END as is_read,
      NULL::TIMESTAMPTZ as read_at,
      'legacy_system'::TEXT as source
    FROM user_notifications un
    WHERE
      un.expires_at > NOW()
      AND (
        un.user_id IS NULL  -- Global notifications
        OR un.user_id = p_user_id  -- Personal notifications
      )
  )
  SELECT * FROM (
    SELECT * FROM new_notifications
    UNION ALL
    SELECT * FROM legacy_notifications
  ) combined
  ORDER BY created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get unread notification count for a user
CREATE OR REPLACE FUNCTION get_unread_notification_count(
  p_user_id UUID
) RETURNS INTEGER AS $$
DECLARE
  new_system_count INTEGER;
  legacy_system_count INTEGER;
BEGIN
  -- Count from new system
  SELECT COUNT(*)::INTEGER INTO new_system_count
  FROM notifications n
  LEFT JOIN notification_reads nr ON n.id = nr.notification_id AND nr.user_id = p_user_id
  WHERE
    n.is_active = TRUE
    AND n.expires_at > NOW()
    AND COALESCE(nr.is_read, FALSE) = FALSE
    AND (
      n.target_type = 'all'
      OR (n.target_type = 'user' AND (n.target_criteria->>'user_id')::UUID = p_user_id)
      OR (n.target_type = 'role' AND 'student' = ANY(
        SELECT jsonb_array_elements_text(n.target_criteria->'target_roles')
      ))
    );

  -- Count from legacy system
  SELECT COUNT(*)::INTEGER INTO legacy_system_count
  FROM user_notifications un
  WHERE
    un.expires_at > NOW()
    AND (
      (un.user_id IS NULL AND NOT (p_user_id::TEXT = ANY(
        SELECT jsonb_array_elements_text(un.metadata->'read_by')
      ))) -- Global unread
      OR (un.user_id = p_user_id) -- Personal (assume unread for legacy)
    );

  RETURN COALESCE(new_system_count, 0) + COALESCE(legacy_system_count, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Migrate data from legacy system to new system
CREATE OR REPLACE FUNCTION migrate_legacy_notifications()
RETURNS TABLE (migrated_count INTEGER, error_count INTEGER) AS $$
DECLARE
  rec RECORD;
  migrated INTEGER := 0;
  errors INTEGER := 0;
  new_notification_id UUID;
BEGIN
  FOR rec IN
    SELECT * FROM user_notifications
    WHERE delivered_at > NOW() - INTERVAL '30 days'  -- Only recent notifications
  LOOP
    BEGIN
      -- Insert into new notifications table
      INSERT INTO notifications (
        type,
        title,
        message,
        target_type,
        target_criteria,
        metadata,
        created_at,
        expires_at
      ) VALUES (
        CASE WHEN rec.user_id IS NULL THEN 'broadcast' ELSE 'personal' END,
        COALESCE(rec.metadata->>'title', 'Legacy Notification'),
        rec.message,
        CASE WHEN rec.user_id IS NULL THEN 'all' ELSE 'user' END,
        CASE
          WHEN rec.user_id IS NULL THEN
            jsonb_build_object('target_roles', ARRAY['student'])
          ELSE
            jsonb_build_object('user_id', rec.user_id)
        END,
        rec.metadata || jsonb_build_object('migrated_from', 'user_notifications'),
        rec.delivered_at,
        rec.expires_at
      ) RETURNING id INTO new_notification_id;

      -- Handle read status migration for personal notifications
      IF rec.user_id IS NOT NULL THEN
        INSERT INTO notification_reads (notification_id, user_id, is_read, created_at)
        VALUES (new_notification_id, rec.user_id, TRUE, rec.delivered_at);
      ELSE
        -- Handle read status for broadcast notifications
        IF rec.metadata ? 'read_by' THEN
          INSERT INTO notification_reads (notification_id, user_id, is_read, read_at, created_at)
          SELECT
            new_notification_id,
            user_id::UUID,
            TRUE,
            rec.delivered_at,
            rec.delivered_at
          FROM jsonb_array_elements_text(rec.metadata->'read_by') AS user_id
          WHERE user_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
        END IF;
      END IF;

      migrated := migrated + 1;

    EXCEPTION WHEN OTHERS THEN
      errors := errors + 1;
      CONTINUE;
    END;
  END LOOP;

  RETURN QUERY SELECT migrated, errors;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions to authenticated users
GRANT EXECUTE ON FUNCTION create_broadcast_notification TO authenticated;
GRANT EXECUTE ON FUNCTION create_personal_notification TO authenticated;
GRANT EXECUTE ON FUNCTION mark_notification_read TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_notifications TO authenticated;
GRANT EXECUTE ON FUNCTION get_unread_notification_count TO authenticated;
GRANT EXECUTE ON FUNCTION migrate_legacy_notifications TO authenticated;