-- Apply Enhanced Notification Migration
-- Run this script in your Supabase SQL Editor or psql

-- Check if migration already applied
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_notifications'
    AND column_name = 'target_criteria'
  ) THEN
    RAISE NOTICE 'Applying enhanced notification migration...';

    -- Run the enhanced notification migration
    \i database/migrations/022_enhance_notification_targeting.sql

    RAISE NOTICE 'Enhanced notification migration applied successfully!';
  ELSE
    RAISE NOTICE 'Enhanced notification migration already applied.';
  END IF;
END $$;

-- Verify migration
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'user_notifications'
AND column_name IN ('target_criteria', 'purchase_id', 'notification_id')
ORDER BY column_name;

-- Check triggers
SELECT
  trigger_name,
  event_object_table,
  action_timing,
  event_manipulation
FROM information_schema.triggers
WHERE trigger_name LIKE '%notification%'
ORDER BY trigger_name;

-- Test notification function exists
SELECT routine_name
FROM information_schema.routines
WHERE routine_name LIKE '%notification%'
AND routine_type = 'FUNCTION'
ORDER BY routine_name;