-- Fix for markAsRead error: PostgrestException(message: record "new" has no field "updated_at", code: 42703)
-- The issue is that there's a trigger trying to update a non-existent 'updated_at' column

-- Drop the problematic trigger and function
DROP TRIGGER IF EXISTS trigger_update_user_notifications_updated_at ON user_notifications;
DROP FUNCTION IF EXISTS update_user_notifications_updated_at();

-- Verify the fix by checking remaining triggers
SELECT
    tgname as trigger_name,
    tgrelid::regclass as table_name,
    proname as function_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgrelid::regclass::text = 'user_notifications'
AND tgname NOT LIKE 'RI_ConstraintTrigger%';