-- Fix profile subscription status for users with active subscriptions
-- Run this in Supabase SQL Editor

-- 1. Fix profile status for users with active subscriptions
UPDATE profiles
SET subscription_status = 'active', updated_at = NOW()
WHERE id IN (
  SELECT DISTINCT user_id
  FROM user_subscriptions
  WHERE status = 'active'
  AND end_date > NOW()
)
AND subscription_status != 'active';

-- 2. Send payment success notifications to users who haven't received them yet
-- (For users with recent active subscriptions but no payment notifications)
DO $$
DECLARE
    user_record RECORD;
    plan_record RECORD;
    expiry_date_str TEXT;
    notification_result JSONB;
BEGIN
    -- Loop through users with active subscriptions who might not have received notifications
    FOR user_record IN
        SELECT DISTINCT
            us.user_id,
            us.subscription_plan_id,
            us.amount,
            us.end_date,
            us.created_at as subscription_created
        FROM user_subscriptions us
        JOIN profiles p ON us.user_id = p.id
        WHERE us.status = 'active'
        AND us.end_date > NOW()
        AND us.created_at > NOW() - INTERVAL '24 hours'  -- Only recent subscriptions
        AND NOT EXISTS (
            SELECT 1 FROM user_notifications un
            WHERE un.user_id = us.user_id
            AND un.metadata->>'type' = 'payment_success'
            AND un.delivered_at > us.created_at - INTERVAL '1 hour'
        )
    LOOP
        -- Get plan details
        SELECT * INTO plan_record
        FROM subscription_plans
        WHERE id = user_record.subscription_plan_id;

        IF FOUND THEN
            -- Format expiry date
            expiry_date_str := TO_CHAR(user_record.end_date, 'DD/MM/YYYY');

            -- Send notification
            SELECT send_payment_success_notification(
                user_record.user_id,
                plan_record.name,
                'RM' || user_record.amount::text,
                expiry_date_str
            ) INTO notification_result;

            RAISE NOTICE 'Sent notification to user % for plan %: %',
                         user_record.user_id, plan_record.name, notification_result;
        END IF;
    END LOOP;
END
$$;

-- 3. Verify the fixes
SELECT
    'Profile Status Fix' as check_type,
    COUNT(*) as fixed_profiles
FROM profiles
WHERE subscription_status = 'active'
AND id IN (
    SELECT DISTINCT user_id
    FROM user_subscriptions
    WHERE status = 'active'
    AND end_date > NOW()
);

-- 4. Show current active subscriptions with profile status
SELECT
    p.id as user_id,
    p.full_name,
    p.subscription_status as profile_status,
    us.status as subscription_status,
    us.subscription_plan_id,
    us.start_date,
    us.end_date,
    sp.name as plan_name
FROM profiles p
JOIN user_subscriptions us ON p.id = us.user_id
JOIN subscription_plans sp ON us.subscription_plan_id = sp.id
WHERE us.status = 'active'
AND us.end_date > NOW()
ORDER BY us.created_at DESC;

-- 5. Show recent notifications
SELECT
    p.full_name,
    un.metadata->>'title' as notification_title,
    un.metadata->>'type' as notification_type,
    un.status,
    un.delivered_at
FROM user_notifications un
JOIN profiles p ON un.user_id = p.id
WHERE un.delivered_at > NOW() - INTERVAL '24 hours'
ORDER BY un.delivered_at DESC;