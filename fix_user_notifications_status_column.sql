-- Fix for payment notifications not appearing
-- Issue: user_notifications table missing 'status' column that Flutter code expects
-- Error: "Could not find the 'status' column of 'user_notifications' in the schema cache"

-- Add status column to user_notifications table
ALTER TABLE user_notifications
ADD COLUMN status TEXT DEFAULT 'unread' CHECK (status IN ('read', 'unread'));

-- Create indexes for better performance on status queries
CREATE INDEX IF NOT EXISTS idx_user_notifications_status ON user_notifications(status);
CREATE INDEX IF NOT EXISTS idx_user_notifications_user_status ON user_notifications(user_id, status);

-- Update existing notifications to have 'unread' status
UPDATE user_notifications SET status = 'unread' WHERE status IS NULL;

-- Verify the fix
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'user_notifications'
ORDER BY ordinal_position;