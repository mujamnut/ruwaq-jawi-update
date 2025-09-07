-- 009: Setup payment and subscription-related tables (ToyyibPay/HitPay compatible)
-- This migration records the new schema introduced for subscription plans, user subscriptions,
-- payments, and webhook logs, along with RLS policies, helper functions, triggers and indexes.
-- Safe to re-run: uses IF NOT EXISTS and CREATE OR REPLACE where appropriate.

-- Create subscription plans table
CREATE TABLE IF NOT EXISTS subscription_plans (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL,
  currency TEXT DEFAULT 'MYR',
  duration_days INTEGER DEFAULT 30,
  features JSONB DEFAULT '[]',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create user subscriptions table
CREATE TABLE IF NOT EXISTS user_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  user_name TEXT,
  subscription_plan_id TEXT REFERENCES subscription_plans(id),
  status TEXT DEFAULT 'pending',
  start_date TIMESTAMP WITH TIME ZONE,
  end_date TIMESTAMP WITH TIME ZONE,
  payment_id TEXT,
  amount DECIMAL(10,2),
  currency TEXT DEFAULT 'MYR',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, subscription_plan_id)
);

-- Create payments table
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  payment_id TEXT UNIQUE NOT NULL,
  reference_number TEXT,
  amount DECIMAL(10,2) NOT NULL,
  currency TEXT DEFAULT 'MYR',
  status TEXT NOT NULL,
  payment_method TEXT DEFAULT 'toyyibpay',
  paid_at TIMESTAMP WITH TIME ZONE,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create webhook logs table
CREATE TABLE IF NOT EXISTS webhook_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider TEXT NOT NULL,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL,
  status TEXT,
  reference_number TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seed subscription plans (idempotent)
INSERT INTO subscription_plans (id, name, description, price, currency, duration_days, features) VALUES
('monthly_basic', 'Asas Bulanan', 'Akses kepada koleksi kitab asas', 19.90, 'MYR', 30, '[]'),
('monthly_premium', 'Premium Bulanan', 'Akses penuh kepada semua kandungan pendidikan Islam', 39.90, 'MYR', 30, '[]'),
('yearly_premium', 'Premium Tahunan', 'Akses penuh dengan penjimatan besar', 399.90, 'MYR', 365, '[]')
ON CONFLICT (id) DO NOTHING;

-- Enable RLS
ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhook_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_subscriptions
DROP POLICY IF EXISTS "Users can view their own subscriptions" ON user_subscriptions;
CREATE POLICY "Users can view their own subscriptions" ON user_subscriptions 
FOR SELECT USING (auth.uid() = user_id);

-- RLS Policies for payments
DROP POLICY IF EXISTS "Users can view their own payments" ON payments;
CREATE POLICY "Users can view their own payments" ON payments 
FOR SELECT USING (auth.uid() = user_id);

-- Service role policies
DROP POLICY IF EXISTS "Service role can manage all subscriptions" ON user_subscriptions;
CREATE POLICY "Service role can manage all subscriptions" ON user_subscriptions 
FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage all payments" ON payments;
CREATE POLICY "Service role can manage all payments" ON payments 
FOR ALL USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Service role can manage webhook logs" ON webhook_logs;
CREATE POLICY "Service role can manage webhook logs" ON webhook_logs 
FOR ALL USING (auth.role() = 'service_role');

-- Add subscription_status column to profiles table if it doesn't exist
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS subscription_status TEXT DEFAULT 'inactive';

-- Function: check active subscription for a user
CREATE OR REPLACE FUNCTION check_active_subscription(user_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM user_subscriptions 
    WHERE user_id = user_uuid 
    AND status = 'active' 
    AND end_date > NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: update profile subscription status
CREATE OR REPLACE FUNCTION update_profile_subscription_status()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE profiles 
  SET subscription_status = CASE 
    WHEN NEW.status = 'active' AND NEW.end_date > NOW() THEN 'active'
    ELSE 'inactive'
  END,
  updated_at = NOW()
  WHERE id = NEW.user_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to sync profiles on subscription changes
DROP TRIGGER IF EXISTS update_profile_on_subscription_change ON user_subscriptions;
CREATE TRIGGER update_profile_on_subscription_change
  AFTER INSERT OR UPDATE ON user_subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION update_profile_subscription_status();

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_id ON user_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_status ON user_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_webhook_logs_created_at ON webhook_logs(created_at);
