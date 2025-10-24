-- Test Migration and New Notification System
-- This file contains test queries to validate the new notification system

-- 1. Test creating a broadcast notification
SELECT create_broadcast_notification(
  'Video Baharu Available!',
  'Episode 19: "Pembahasan Manhaj Hadith" telah ditambah dalam kitab "Majlis Hadith Nabawi".',
  '{"icon": "🎬", "content_type": "video_episode", "content_id": "test-episode-id", "action_url": "/kitab"}'::jsonb,
  ARRAY['student']
);

-- 2. Test creating a personal notification
SELECT create_personal_notification(
  '6cfe0f2d-7432-429c-8f0d-15ba5a70b8bb'::uuid,
  'Selamat Datang!',
  'Terima kasih kerana mendaftar di Maktabah Ruwaq Jawi. Mulakan pembelajaran anda hari ini!',
  '{"icon": "👋", "type": "welcome", "action_url": "/home"}'::jsonb
);

-- 3. Test getting notifications for a user
SELECT * FROM get_user_notifications('6cfe0f2d-7432-429c-8f0d-15ba5a70b8bb'::uuid, 10, 0);

-- 4. Test getting unread count
SELECT get_unread_notification_count('6cfe0f2d-7432-429c-8f0d-15ba5a70b8bb'::uuid);

-- 5. Test marking notification as read
-- First get a notification ID from the previous query, then:
-- SELECT mark_notification_read('notification-id-here'::uuid, '6cfe0f2d-7432-429c-8f0d-15ba5a70b8bb'::uuid);

-- 6. Check new tables structure
SELECT
  n.id,
  n.type,
  n.title,
  n.target_type,
  n.created_at,
  COUNT(nr.id) as read_count
FROM notifications n
LEFT JOIN notification_reads nr ON n.id = nr.notification_id
GROUP BY n.id, n.type, n.title, n.target_type, n.created_at
ORDER BY n.created_at DESC;

-- 7. Check legacy table for comparison
SELECT
  id,
  CASE WHEN user_id IS NULL THEN 'broadcast' ELSE 'personal' END as type,
  metadata->>'title' as title,
  delivered_at as created_at,
  array_length(ARRAY(SELECT jsonb_array_elements_text(metadata->'read_by')), 1) as read_count
FROM user_notifications
ORDER BY delivered_at DESC
LIMIT 10;

-- 8. Performance test - check indexes
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM get_user_notifications('6cfe0f2d-7432-429c-8f0d-15ba5a70b8bb'::uuid, 20, 0);

-- 9. Test migration function (will migrate legacy data)
-- SELECT * FROM migrate_legacy_notifications();

-- 10. Cleanup test data (uncomment to remove test notifications)
/*
DELETE FROM notification_reads WHERE notification_id IN (
  SELECT id FROM notifications WHERE metadata->>'content_id' = 'test-episode-id'
);
DELETE FROM notifications WHERE metadata->>'content_id' = 'test-episode-id';
*/