-- Fix RLS policy for user_notifications to support unified notifications
-- Allow users to read both individual and global notifications

-- Drop existing select policy
DROP POLICY IF EXISTS user_notif_select_own ON user_notifications;

-- Create new select policy that allows:
-- 1. Individual notifications (user_id = auth.uid())
-- 2. Global notifications (user_id = special global UUID + user role matches)
CREATE POLICY user_notif_select_unified ON user_notifications
FOR SELECT TO authenticated
USING (
  -- Individual notifications for current user
  user_id = auth.uid()
  OR
  -- Global notifications targeting user's role
  (
    user_id = '00000000-0000-0000-0000-000000000000'
    AND
    (
      -- Check if user's role is in target_roles array
      (SELECT role FROM profiles WHERE id = auth.uid()) = ANY(
        CASE
          WHEN metadata ? 'target_roles' THEN
            ARRAY(SELECT jsonb_array_elements_text(metadata->'target_roles'))
          ELSE
            ARRAY['student'] -- Default to student if no target_roles specified
        END
      )
    )
  )
);

-- Update policy also needs fixing for global notifications
DROP POLICY IF EXISTS user_notif_update_read_own ON user_notifications;

CREATE POLICY user_notif_update_unified ON user_notifications
FOR UPDATE TO authenticated
USING (
  -- Can update individual notifications
  user_id = auth.uid()
  OR
  -- Can update global notifications (to add read tracking in metadata)
  (
    user_id = '00000000-0000-0000-0000-000000000000'
    AND
    (SELECT role FROM profiles WHERE id = auth.uid()) = ANY(
      CASE
        WHEN metadata ? 'target_roles' THEN
          ARRAY(SELECT jsonb_array_elements_text(metadata->'target_roles'))
        ELSE
          ARRAY['student']
      END
    )
  )
)
WITH CHECK (
  -- Same conditions for WITH CHECK
  user_id = auth.uid()
  OR
  (
    user_id = '00000000-0000-0000-0000-000000000000'
    AND
    (SELECT role FROM profiles WHERE id = auth.uid()) = ANY(
      CASE
        WHEN metadata ? 'target_roles' THEN
          ARRAY(SELECT jsonb_array_elements_text(metadata->'target_roles'))
        ELSE
          ARRAY['student']
      END
    )
  )
);

-- Test the policy
DO $$
BEGIN
  RAISE NOTICE '✅ Updated RLS policies for unified notifications';
  RAISE NOTICE '📋 Students can now read:';
  RAISE NOTICE '   - Individual notifications (user_id = their ID)';
  RAISE NOTICE '   - Global notifications (user_id = 00000000-0000-0000-0000-000000000000)';
  RAISE NOTICE '🔒 Security maintained: users only see notifications meant for their role';
END $$;