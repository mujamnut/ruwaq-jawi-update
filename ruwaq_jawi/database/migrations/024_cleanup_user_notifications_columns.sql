-- Clean up user_notifications table to keep only essential 7 columns
-- Remove unused columns for unified notification system efficiency

-- Drop unused columns that are not needed
ALTER TABLE user_notifications
DROP COLUMN IF EXISTS read_at,
DROP COLUMN IF EXISTS delivery_status,
DROP COLUMN IF EXISTS is_favorite,
DROP COLUMN IF EXISTS updated_at,
DROP COLUMN IF EXISTS purchase_id;

-- Update table comment to reflect the simplified structure
COMMENT ON TABLE user_notifications IS 'Unified notification table with 7 essential columns for both individual and global notifications';

-- Document the final column structure
COMMENT ON COLUMN user_notifications.id IS 'Primary key UUID';
COMMENT ON COLUMN user_notifications.user_id IS 'User UUID (nullable) - use 00000000-0000-0000-0000-000000000000 for global notifications';
COMMENT ON COLUMN user_notifications.message IS 'Notification message text';
COMMENT ON COLUMN user_notifications.metadata IS 'JSON containing title, body, type, target_roles, etc.';
COMMENT ON COLUMN user_notifications.status IS 'Notification status (unread/read)';
COMMENT ON COLUMN user_notifications.target_criteria IS 'JSON targeting information';
COMMENT ON COLUMN user_notifications.delivered_at IS 'Timestamp when notification was created/delivered';

-- Verify the cleanup
DO $$
DECLARE
    col_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns
    WHERE table_name = 'user_notifications';

    RAISE NOTICE '✅ user_notifications table now has % columns (should be 7)', col_count;

    IF col_count = 7 THEN
        RAISE NOTICE '🎯 Perfect! Table structure optimized for unified notifications';
    ELSE
        RAISE NOTICE '⚠️ Expected 7 columns, got %', col_count;
    END IF;
END $$;