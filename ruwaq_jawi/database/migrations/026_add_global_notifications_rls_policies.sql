-- Add RLS policies for global_notifications and user_notification_reads tables
-- This allows admins to manage global notifications and users to read notifications for their role

-- Enable RLS on global_notifications table
ALTER TABLE global_notifications ENABLE ROW LEVEL SECURITY;

-- Enable RLS on user_notification_reads table
ALTER TABLE user_notification_reads ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS Policies for global_notifications table
-- ============================================================================

-- Policy 1: Admins can do everything (SELECT, INSERT, UPDATE, DELETE)
CREATE POLICY "Admins can manage global notifications" ON global_notifications
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Policy 2: Students can read active global notifications for their role
CREATE POLICY "Users can read global notifications for their role" ON global_notifications
  FOR SELECT
  TO authenticated
  USING (
    is_active = true
    AND (expires_at IS NULL OR expires_at > NOW())
    AND (
      -- Check if user's role is in target_roles array
      (SELECT role FROM profiles WHERE id = auth.uid()) = ANY(target_roles)
    )
  );

-- ============================================================================
-- RLS Policies for user_notification_reads table
-- ============================================================================

-- Policy 1: Users can view their own read notifications
CREATE POLICY "Users can view their own notification reads" ON user_notification_reads
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Policy 2: Users can insert their own read records
CREATE POLICY "Users can mark notifications as read" ON user_notification_reads
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Policy 3: Admins can view all notification reads (for statistics)
CREATE POLICY "Admins can view all notification reads" ON user_notification_reads
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Policy 4: Admins can delete notification reads (for cleanup)
CREATE POLICY "Admins can delete notification reads" ON user_notification_reads
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- ============================================================================
-- Documentation
-- ============================================================================

COMMENT ON POLICY "Admins can manage global notifications" ON global_notifications IS
  'Allows admins to create, read, update, and delete global notifications';

COMMENT ON POLICY "Users can read global notifications for their role" ON global_notifications IS
  'Allows users to read active, non-expired global notifications that target their role';

COMMENT ON POLICY "Users can view their own notification reads" ON user_notification_reads IS
  'Allows users to view which notifications they have marked as read';

COMMENT ON POLICY "Users can mark notifications as read" ON user_notification_reads IS
  'Allows users to mark notifications as read by inserting into user_notification_reads';

COMMENT ON POLICY "Admins can view all notification reads" ON user_notification_reads IS
  'Allows admins to view all read status records for statistics and analytics';

COMMENT ON POLICY "Admins can delete notification reads" ON user_notification_reads IS
  'Allows admins to cleanup read records when deleting notifications';

-- ============================================================================
-- Test the policies
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '✅ RLS policies added for global_notifications and user_notification_reads';
  RAISE NOTICE '🔐 Security configured:';
  RAISE NOTICE '   📝 Admins: Full control over global notifications (CREATE, READ, UPDATE, DELETE)';
  RAISE NOTICE '   👁️  Students: Can read active notifications targeting their role';
  RAISE NOTICE '   ✔️  All users: Can mark their own notifications as read';
  RAISE NOTICE '   📊 Admins: Can view all read statistics for analytics';
END $$;
