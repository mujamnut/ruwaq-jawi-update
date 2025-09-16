-- Test Enhanced Notification System
-- Run this in Supabase SQL Editor to test the system

-- 1. Test subscription expiry notifications
SELECT trigger_subscription_expiry_check() AS subscription_expiry_test;

-- 2. Test inactive user notifications
SELECT trigger_inactive_user_notification() AS inactive_user_test;

-- 3. View recent notifications
SELECT
  un.id,
  un.user_id,
  un.message,
  un.status,
  un.delivery_status,
  un.target_criteria,
  un.purchase_id,
  un.delivered_at,
  p.full_name,
  p.role
FROM user_notifications un
LEFT JOIN profiles p ON p.id = un.user_id
WHERE un.delivered_at > NOW() - INTERVAL '1 hour'
ORDER BY un.delivered_at DESC;

-- 4. Test manual notification trigger via SQL
-- This simulates what happens when new content is added
INSERT INTO user_notifications (
  user_id,
  message,
  metadata,
  status,
  delivery_status,
  target_criteria,
  delivered_at
)
SELECT
  p.id,
  E'🧪 Test Notification\nSistem notifikasi berjalan dengan baik!',
  jsonb_build_object(
    'title', '🧪 Test Notification',
    'body', 'Sistem notifikasi berjalan dengan baik!',
    'type', 'admin_announcement',
    'icon', '🧪',
    'action_url', '/notifications',
    'data', jsonb_build_object('test', true),
    'created_at', NOW()
  ),
  'unread',
  'delivered',
  jsonb_build_object(
    'admin_announcement', true,
    'priority', 'low',
    'test_notification', true
  ),
  NOW()
FROM profiles p
WHERE p.role = 'admin'
LIMIT 1;

-- 5. Check trigger functions exist
SELECT
  routine_name,
  routine_type,
  routine_definition
FROM information_schema.routines
WHERE routine_name LIKE '%notification%'
AND routine_type = 'FUNCTION';

-- 6. Check triggers are active
SELECT
  trigger_name,
  event_object_table,
  action_timing,
  event_manipulation,
  action_statement
FROM information_schema.triggers
WHERE trigger_name LIKE '%notification%';

-- 7. Check subscription data structure and profile columns
SELECT
  us.id,
  us.user_id,
  us.subscription_plan_id,
  us.status,
  us.start_date,
  us.end_date,
  sp.name as plan_name,
  p.full_name,
  p.role,
  p.updated_at as profile_last_activity,
  us.updated_at as subscription_last_activity
FROM user_subscriptions us
JOIN subscription_plans sp ON us.subscription_plan_id = sp.id
JOIN profiles p ON us.user_id = p.id
ORDER BY us.created_at DESC
LIMIT 5;

-- Check profiles table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles'
ORDER BY ordinal_position;

-- Test update_user_last_seen function
SELECT update_user_last_seen(id) as last_seen_update
FROM profiles
WHERE role = 'admin'
LIMIT 1;

-- View profiles with last_seen_at info
SELECT
  id,
  full_name,
  role,
  updated_at,
  last_seen_at,
  CASE
    WHEN last_seen_at IS NULL THEN 'Never logged activity'
    WHEN last_seen_at < (NOW() - INTERVAL '7 days') THEN 'Inactive > 7 days'
    WHEN last_seen_at < (NOW() - INTERVAL '1 day') THEN 'Inactive > 1 day'
    ELSE 'Active'
  END as activity_status
FROM profiles
ORDER BY last_seen_at DESC NULLS LAST
LIMIT 10;

-- 8. Test payment notification trigger
-- This simulates a successful payment
UPDATE payments
SET status = 'completed'
WHERE status = 'pending'
AND user_id IS NOT NULL
LIMIT 1;

-- 9. Test content notification trigger
-- This simulates activating new content
UPDATE video_kitab
SET is_active = true
WHERE is_active = false
LIMIT 1;

-- View results
SELECT
  'Total notifications today' as metric,
  COUNT(*) as value
FROM user_notifications
WHERE delivered_at::date = CURRENT_DATE

UNION ALL

SELECT
  'Unread notifications' as metric,
  COUNT(*) as value
FROM user_notifications
WHERE status = 'unread'

UNION ALL

SELECT
  'Admin notifications' as metric,
  COUNT(*) as value
FROM user_notifications un
JOIN profiles p ON p.id = un.user_id
WHERE p.role = 'admin'
AND un.delivered_at::date = CURRENT_DATE

UNION ALL

SELECT
  'Student notifications' as metric,
  COUNT(*) as value
FROM user_notifications un
JOIN profiles p ON p.id = un.user_id
WHERE p.role = 'student'
AND un.delivered_at::date = CURRENT_DATE;