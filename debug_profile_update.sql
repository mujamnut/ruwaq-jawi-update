-- Debug script untuk test profile subscription_status update
-- Jalankan di Supabase SQL Editor untuk debug masalah

-- 1. Semak struktur table profiles
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'profiles' AND table_schema = 'public';

-- 2. Semak RLS policies untuk profiles
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'profiles';

-- 3. Semak current profiles data (ganti USER_ID_HERE dengan UUID user sebenar)
-- SELECT id, full_name, subscription_status, updated_at 
-- FROM profiles 
-- WHERE id = 'USER_ID_HERE';

-- 4. Test manual update (ganti USER_ID_HERE dengan UUID user sebenar)
-- UPDATE profiles 
-- SET subscription_status = 'active', updated_at = NOW() 
-- WHERE id = 'USER_ID_HERE';

-- 5. Semak user_subscriptions untuk user tersebut
-- SELECT * FROM user_subscriptions WHERE user_id = 'USER_ID_HERE';

-- 6. Test trigger function secara manual
-- INSERT INTO user_subscriptions (user_id, subscription_plan_id, status, start_date, end_date, payment_id, amount) 
-- VALUES ('USER_ID_HERE', 'monthly_basic', 'active', NOW(), NOW() + INTERVAL '30 days', 'test123', 19.90);

-- 7. Semak webhook logs untuk debug
SELECT * FROM webhook_logs 
ORDER BY created_at DESC 
LIMIT 10;

-- 8. Semak payments table
SELECT user_id, payment_id, status, amount, created_at 
FROM payments 
ORDER BY created_at DESC 
LIMIT 10;

-- 9. Test function check_active_subscription (ganti USER_ID_HERE)
-- SELECT check_active_subscription('USER_ID_HERE');

-- 10. Semak trigger ada atau tidak
SELECT trigger_name, event_manipulation, event_object_table, action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'user_subscriptions';
