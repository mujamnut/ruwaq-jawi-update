-- Fix subscription plans in database
-- Run this in your Supabase SQL Editor

-- First, update existing subscription plans to match your client code
INSERT INTO subscription_plans (id, name, description, price, currency, duration_days, features, is_active) VALUES
('monthly_basic', 'Monthly Basic', 'Access to basic Islamic content library', 19.90, 'MYR', 30, '["Access to 100+ Islamic books", "Basic video lectures", "Mobile app access", "Email support"]'::jsonb, true),
('monthly_premium', 'Monthly Premium', 'Full access to all Islamic educational content', 39.90, 'MYR', 30, '["Access to 500+ Islamic books", "Premium video lectures", "Offline download", "Priority support", "Advanced search features"]'::jsonb, true),
('yearly_premium', 'Yearly Premium', 'Full access with significant savings', 399.90, 'MYR', 365, '["Access to 500+ Islamic books", "Premium video lectures", "Offline download", "Priority support", "Advanced search features", "2 months free"]'::jsonb, true)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  price = EXCLUDED.price,
  duration_days = EXCLUDED.duration_days,
  features = EXCLUDED.features,
  updated_at = NOW();

-- Create missing plans that your payment provider expects
INSERT INTO subscription_plans (id, name, description, price, currency, duration_days, features, is_active) VALUES
('quarterly_premium', 'Quarterly Premium', '3 months premium access', 99.90, 'MYR', 90, '["Access to 500+ Islamic books", "Premium video lectures", "Offline download", "Priority support", "Advanced search features"]'::jsonb, true),
('semiannual_premium', '6 Months Premium', '6 months premium access with savings', 179.90, 'MYR', 180, '["Access to 500+ Islamic books", "Premium video lectures", "Offline download", "Priority support", "Advanced search features", "1 month free"]'::jsonb, true)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  price = EXCLUDED.price,
  duration_days = EXCLUDED.duration_days,
  features = EXCLUDED.features,
  updated_at = NOW();

-- Verify the plans
SELECT id, name, price, duration_days, is_active FROM subscription_plans ORDER BY duration_days;

-- Check if there are any orphaned subscriptions that need to be synced
SELECT 
  s.user_id,
  s.plan_type,
  s.status as old_status,
  s.end_date as old_end_date,
  us.status as new_status,
  us.end_date as new_end_date,
  p.subscription_status as profile_status
FROM subscriptions s
FULL OUTER JOIN user_subscriptions us ON s.user_id = us.user_id
LEFT JOIN profiles p ON s.user_id = p.id
WHERE s.status = 'active' OR us.status = 'active'
ORDER BY s.created_at DESC, us.created_at DESC;
