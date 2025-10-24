-- Update Notification Functions with Registration Date Filter
-- Execute this in Supabase SQL Editor
-- Author: Assistant
-- Date: 2025-09-22

-- 1. Update get_user_notifications function
CREATE OR REPLACE FUNCTION get_user_notifications(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
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
    SELECT
        n.id,
        n.type,
        n.title,
        n.message,
        n.metadata,
        n.created_at,
        COALESCE(nr.is_read, false) as is_read,
        nr.read_at,
        'new_system'::text as source
    FROM notifications n
    JOIN auth.users u ON u.id = p_user_id
    LEFT JOIN notification_reads nr ON n.id = nr.notification_id AND nr.user_id = p_user_id
    WHERE
        n.is_active = true
        AND (n.expires_at IS NULL OR n.expires_at > NOW())
        AND n.created_at >= u.created_at  -- 🎯 NEW: Only show notifications created after user registration
        AND (
            (n.target_type = 'all') OR
            (n.target_type = 'user' AND n.target_criteria->>'user_id' = p_user_id::text) OR
            (n.target_type = 'role' AND EXISTS (
                SELECT 1 FROM profiles p
                WHERE p.id = p_user_id
                AND p.role::text = ANY(
                    SELECT jsonb_array_elements_text(n.target_criteria->'target_roles')
                )
            ))
        )
    ORDER BY n.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Update get_unread_notification_count function
CREATE OR REPLACE FUNCTION get_unread_notification_count(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    unread_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO unread_count
    FROM notifications n
    JOIN auth.users u ON u.id = p_user_id
    LEFT JOIN notification_reads nr ON n.id = nr.notification_id AND nr.user_id = p_user_id
    WHERE
        n.is_active = true
        AND (n.expires_at IS NULL OR n.expires_at > NOW())
        AND n.created_at >= u.created_at  -- 🎯 NEW: Only count notifications created after user registration
        AND (nr.is_read IS NULL OR nr.is_read = false)
        AND (
            (n.target_type = 'all') OR
            (n.target_type = 'user' AND n.target_criteria->>'user_id' = p_user_id::text) OR
            (n.target_type = 'role' AND EXISTS (
                SELECT 1 FROM profiles p
                WHERE p.id = p_user_id
                AND p.role::text = ANY(
                    SELECT jsonb_array_elements_text(n.target_criteria->'target_roles')
                )
            ))
        );

    RETURN COALESCE(unread_count, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Test query to verify the changes work
-- Uncomment and run this after executing the functions above:

/*
-- Test with existing user to see if they still get their notifications
SELECT
    u.id as user_id,
    u.created_at as user_registered_at,
    COUNT(*) as notification_count
FROM auth.users u
CROSS JOIN notifications n
WHERE n.created_at >= u.created_at
  AND n.is_active = true
GROUP BY u.id, u.created_at
ORDER BY u.created_at DESC;

-- Test unread count function
SELECT get_unread_notification_count('3182405e-c699-4968-a0ef-cf495eafc03b'::uuid) as unread_count;
*/